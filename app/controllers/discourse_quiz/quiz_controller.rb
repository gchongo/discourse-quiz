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

      question = QuizQuestion.pick_random(category_names: category_filters)

      unless question
        return(
          render_json_dump(
            { error: I18n.t("discourse_quiz.errors.no_active_questions") },
            status: 404,
          )
        )
      end

      render_json_dump(
        {
          id: question.id,
          category_name: question.category_name,
          question_text: question.question_text,
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
      render_json_dump(categories: QuizQuestion.category_names)
    end

    def status
      render_json_dump(quiz_status)
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

      submission = QuizSubmissionService.new(current_user, question, params[:answer_index])
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

    def category_filters
      setting = SiteSetting.quiz_categories.to_s.strip
      return [] if setting.blank?

      setting.split(",").map(&:strip).reject(&:blank?)
    end
  end
end
