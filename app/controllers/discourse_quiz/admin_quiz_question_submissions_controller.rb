# frozen_string_literal: true

module DiscourseQuiz
  class AdminQuizQuestionSubmissionsController < ::Admin::AdminController
    requires_plugin DiscourseQuiz::PLUGIN_NAME
    DEFAULT_PER_PAGE = 20
    MAX_PER_PAGE = 100
    CREATED_WINDOWS = %w[all today 7d 30d 90d].freeze

    def index
      with_primary_read do
        scope = filtered_submissions_scope
        page = [params[:page].to_i, 1].max
        per_page = per_page_param
        total = scope.count
        offset = (page - 1) * per_page

        render_json_dump(
          submissions: scope.offset(offset).limit(per_page).map { |submission| submission_json(submission) },
          categories: QuizQuestionSubmission.distinct.order(:category_name).pluck(:category_name),
          total: total,
          page: page,
          per_page: per_page,
        )
      end
    rescue StandardError => e
      Rails.logger.error("[discourse-quiz] admin question submissions index failed: #{e.class}: #{e.message}")
      render_json_dump(
        {
          submissions: [],
          categories: [],
          total: 0,
          page: 1,
          per_page: DEFAULT_PER_PAGE,
          error: I18n.t("discourse_quiz.errors.database_unavailable"),
        },
        status: 500,
      )
    end

    def update
      submission = QuizQuestionSubmission.find_by(id: params[:id])
      return render_not_found unless submission

      if submission.status != "pending"
        return render_json_dump(
                 { error: I18n.t("discourse_quiz.errors.invalid_status") },
                 status: 422,
               )
      end

      action = params[:review_action].to_s
      note = params[:review_note].to_s.strip.presence

      case action
      when "approve"
        question = submission.approve!(reviewer: current_user, review_note: note)
        reward_result = QuizSubmissionRewardService.reward_for_approved_submission(submission)
        QuizSubmissionNotificationService.notify_approved(
          submission: submission,
          review_note: note,
          points_awarded: reward_result[:awarded_points],
        )
        render_json_dump(
          submission: submission_json(submission),
          question_id: question.id,
          submission_reward_points_awarded: reward_result[:awarded_points].to_i,
          submission_reward_reason: reward_result[:reason].to_s,
        )
      when "reject"
        submission.reject!(reviewer: current_user, review_note: note)
        QuizSubmissionNotificationService.notify_rejected(submission: submission, review_note: note)
        render_json_dump(submission: submission_json(submission))
      else
        render_json_dump({ error: I18n.t("discourse_quiz.errors.invalid_status") }, status: 422)
      end
    end

    def edit_submission
      submission = QuizQuestionSubmission.find_by(id: params[:id])
      return render_not_found unless submission

      if submission.status != "pending"
        return render_json_dump(
                 { error: I18n.t("discourse_quiz.errors.invalid_status") },
                 status: 422,
               )
      end

      submission.assign_attributes(submission_attributes)

      if submission.save
        render_json_dump(submission: submission_json(submission))
      else
        render_json_dump({ errors: submission.errors.full_messages }, status: 422)
      end
    end

    private

    def render_not_found
      render_json_dump({ error: I18n.t("discourse_quiz.errors.question_not_found") }, status: 404)
    end

    def with_primary_read(&block)
      if defined?(DB) && DB.respond_to?(:use_primary)
        DB.use_primary(&block)
      else
        yield
      end
    end

    def filtered_submissions_scope
      scope = QuizQuestionSubmission.recent_first
      status_filter = normalize_status_filter(params[:status])

      if status_filter == "pending"
        scope = scope.where("LOWER(COALESCE(NULLIF(TRIM(status), ''), 'pending')) = 'pending'")
      elsif status_filter.present?
        scope = scope.where("LOWER(TRIM(status)) = ?", status_filter)
      end

      if params[:category_name].present?
        scope = scope.where(category_name: params[:category_name].to_s.strip)
      end

      question_type = params[:question_type].to_s
      if %w[single_choice true_false multiple_choice].include?(question_type)
        scope = scope.where(question_type: question_type)
      end

      created_window = normalize_created_window(params[:created_window])
      scope = scope.where("created_at >= ?", created_window_start(created_window)) if created_window != "all"

      query_text = params[:q].to_s.strip
      if query_text.present?
        scope = scope.where(
          "question_text ILIKE :query OR category_name ILIKE :query OR submitter_username ILIKE :query",
          query: "%#{query_text}%",
        )
      end

      scope
    end

    def normalize_status_filter(status)
      value = status.to_s.strip
      return nil if value.blank?

      %w[pending approved rejected].include?(value) ? value : nil
    end

    def normalize_created_window(window)
      value = window.to_s.strip
      return "all" if value.blank?

      CREATED_WINDOWS.include?(value) ? value : "all"
    end

    def created_window_start(window)
      case window
      when "today"
        Time.zone.now.beginning_of_day
      when "7d"
        7.days.ago
      when "30d"
        30.days.ago
      when "90d"
        90.days.ago
      else
        100.years.ago
      end
    end

    def per_page_param
      per_page = params[:per_page].to_i
      per_page = DEFAULT_PER_PAGE if per_page <= 0
      [per_page, MAX_PER_PAGE].min
    end

    def submission_attributes
      attrs =
        params.require(:submission).permit(
          :category_name,
          :question_text,
          :question_type,
          :correct_index,
          :explanation,
          :show_author_name,
          options: [],
          correct_indices: [],
        )

      if attrs[:options].is_a?(String)
        attrs[:options] = attrs[:options].split(/\r?\n/).map(&:strip).reject(&:blank?)
      end

      unless QuizQuestionSubmission.column_names.include?("show_author_name")
        attrs.delete(:show_author_name)
      end

      attrs
    end

    def submission_json(submission)
      {
        id: submission.id,
        submitter_id: submission.submitter_id,
        submitter_username: submission.submitter_username,
        category_name: submission.category_name,
        question_text: submission.question_text,
        question_type: submission.question_type,
        options: submission.options,
        correct_index: submission.correct_index,
        correct_indices: submission.correct_indices,
        explanation: submission.explanation,
        show_author_name: submission.respond_to?(:show_author_name) ? submission.show_author_name : true,
        status: submission.status.presence || "pending",
        review_note: submission.review_note,
        reviewer_id: submission.reviewer_id,
        reviewed_at: format_datetime(submission.reviewed_at),
        approved_question_id: submission.approved_question_id,
        created_at: format_datetime(submission.created_at),
      }
    end

    def format_datetime(value)
      return nil unless value

      value.in_time_zone.strftime("%Y-%m-%d %H:%M:%S")
    end
  end
end
