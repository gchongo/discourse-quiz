# frozen_string_literal: true

module DiscourseQuiz
  class QuizController < ::ApplicationController
    requires_plugin DiscourseQuiz::PLUGIN_NAME

    before_action :ensure_enabled
    before_action :ensure_can_play, only: %i[next submit]

    def next
      unless table_ready?
        return(
          render_json_dump(
            { error: I18n.t("discourse_quiz.errors.database_unavailable") },
            status: 503,
          )
        )
      end

      picker = build_question_picker
      return if performed?

      question = picker.pick

      unless question
        return(
          render_json_dump(
            {
              error: empty_questions_message(picker.empty_reason),
              error_code: picker.empty_reason || :no_active_questions,
            },
            status: 404,
          )
        )
      end

      render_json_dump(
        {
          id: question.id,
          author_username: resolve_author_username(question),
          category_name: question.category_name,
          question_text: question.question_text,
          question_type: question.resolved_question_type,
          options: question.options,
          status: quiz_status,
        },
      )
    rescue ActiveRecord::StatementInvalid => e
      Rails.logger.error("[discourse-quiz] quiz#next failed: #{e.message}")
      render_json_dump(
        { error: I18n.t("discourse_quiz.errors.database_unavailable") },
        status: 503,
      )
    end

    def categories
      render_json_dump(
        categories: QuizQuestion.available_category_names(allowed: site_category_allowlist),
        status: quiz_status,
      )
    end

    def status
      render_json_dump(quiz_status)
    end

    def summary_stats
      raise Discourse::InvalidAccess unless current_user

      unless DiscourseQuiz::QuizUserAttempt.table_ready?
        return(
          render_json_dump(
            { error: I18n.t("discourse_quiz.errors.database_unavailable") },
            status: 503,
          )
        )
      end

      summary =
        QuizStatsService.new(current_user).summary(
          category_names: site_category_allowlist,
        )

      render_json_dump(
        quiz_summary_stats: {
          lifetime_correct: summary[:lifetime_correct],
          wrong_questions: summary[:wrong_questions],
          accuracy_rate: summary[:accuracy_rate],
        },
      )
    end

    def submit
      unless table_ready?
        return(
          render_json_dump(
            { error: I18n.t("discourse_quiz.errors.database_unavailable") },
            status: 503,
          )
        )
      end

      ensure_not_rate_limited!
      return if performed?

      question = QuizQuestion.active.find_by(id: params[:question_id].to_i)
      unless question
        return(
          render_json_dump(
            { error: I18n.t("discourse_quiz.errors.question_not_found") },
            status: 404,
          )
        )
      end

      submission =
        QuizSubmissionService.new(
          current_user,
          question,
          answer_index: params[:answer_index],
          answer_indices: submit_answer_indices,
        )
      result = submission.submit
      return render_json_dump(result, status: submission.status_code) if submission.failed?

      unless current_user
        session[:quiz_guest_attempts] = guest_attempts_count + 1
      end

      result[:status] = quiz_status
      render_json_dump(result)
    rescue ActiveRecord::StatementInvalid => e
      Rails.logger.error("[discourse-quiz] quiz#submit failed: #{e.message}")
      render_json_dump(
        { error: I18n.t("discourse_quiz.errors.database_unavailable") },
        status: 503,
      )
    end

    private

    def ensure_enabled
      raise Discourse::NotFound unless SiteSetting.quiz_plugin_enabled
    end

    def ensure_can_play
      return if status_service.can_play?

      render_json_dump(
        {
          error: I18n.t("discourse_quiz.errors.paywall_reached"),
          status: quiz_status,
        },
        status: 403,
      )
      false
    end

    def ensure_not_rate_limited!
      limit = SiteSetting.quiz_submit_cooldown_seconds
      return if limit <= 0

      if current_user
        RateLimiter.new(current_user, "quiz-submit", 1, limit).performed!
      else
        RateLimiter.new(nil, "quiz-submit-#{request.remote_ip}", 1, limit).performed!
      end
    rescue RateLimiter::LimitExceeded => e
      render_json_error(e.description, status: 429)
    end

    def quiz_status
      status_service.get_status
    end

    def status_service
      @status_service ||= QuizStatusService.new(current_user, guest_attempts_count)
    end

    def guest_attempts_count
      session[:quiz_guest_attempts].to_i
    end

    def table_ready?
      ActiveRecord::Base.connection.table_exists?(:discourse_quiz_questions)
    end

    def site_category_allowlist
      setting = SiteSetting.quiz_categories.to_s.strip
      return [] if setting.blank?

      setting.split(",").map(&:strip).reject(&:blank?)
    end

    def effective_category_filters
      allowlist = site_category_allowlist
      selected = selected_category_names

      if selected.present?
        validated = validate_selected_categories(selected, allowlist)
        return validated if validated.present?

        return []
      end

      allowlist
    end

    def selected_category_names
      names =
        if params[:category_names].present?
          Array(params[:category_names])
        elsif params[:category_name].present?
          [params[:category_name]]
        else
          []
        end

      names.map(&:to_s).map(&:strip).reject(&:blank?).uniq
    end

    def validate_selected_categories(names, allowlist)
      if allowlist.present?
        names.select { |name| allowlist.include?(name) }
      else
        available = QuizQuestion.active_category_names
        names.select { |name| available.include?(name) }
      end
    end

    def build_question_picker
      practice_mode = normalized_practice_mode

      if practice_mode != "normal" && current_user.nil?
        render_json_dump(
          {
            error: I18n.t("discourse_quiz.errors.practice_mode_requires_login"),
            error_code: :practice_mode_requires_login,
            status: quiz_status,
          },
          status: 403,
        )
        return nil
      end

      QuizQuestionPicker.new(
        user: current_user,
        category_names: effective_category_filters,
        practice_mode: practice_mode,
        exclude_question_ids: session_exclude_question_ids,
        question_types: effective_question_type_filters,
      )
    end

    def session_exclude_question_ids
      Array(params[:exclude_question_ids]).map(&:to_i).reject(&:zero?).uniq
    end

    def submit_answer_indices
      Array(params[:answer_indices]).map(&:to_i).reject(&:negative?).uniq
    end

    def normalized_practice_mode
      mode = params[:practice_mode].to_s
      QuizQuestionPicker::MODES.include?(mode) ? mode : "normal"
    end

    def effective_question_type_filters
      Array(params[:question_types])
        .map(&:to_s)
        .select { |type| QuestionTypes::ALL.include?(type) }
        .uniq
    end

    def empty_questions_message(reason)
      key =
        case reason
        when :no_wrong_questions
          "discourse_quiz.errors.no_wrong_questions"
        when :no_unseen_questions
          "discourse_quiz.errors.no_unseen_questions"
        else
          "discourse_quiz.errors.no_active_questions"
        end

      I18n.t(key)
    end

    def resolve_author_username(question)
      return nil unless question.respond_to?(:author_username)
      return nil if question.respond_to?(:show_author_name) && !question.show_author_name

      question.author_username
    end
  end
end
