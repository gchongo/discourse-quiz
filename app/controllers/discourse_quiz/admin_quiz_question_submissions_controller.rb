# frozen_string_literal: true

module DiscourseQuiz
  class AdminQuizQuestionSubmissionsController < ::Admin::AdminController
    requires_plugin DiscourseQuiz::PLUGIN_NAME

    def index
      submissions = []

      DB.use_primary do
        scope = QuizQuestionSubmission.recent_first
        status_filter = normalize_status_filter(params[:status])

        if status_filter == "pending"
          scope =
            scope.where(
              "LOWER(COALESCE(NULLIF(TRIM(status), ''), 'pending')) = 'pending'",
            )
        elsif status_filter.present?
          scope = scope.where("LOWER(TRIM(status)) = ?", status_filter)
        end

        submissions = scope.limit(200).to_a
      end

      render_json_dump(
        submissions: submissions.map { |submission| submission_json(submission) },
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
        render_json_dump(
          submission: submission_json(submission),
          question_id: question.id,
        )
      when "reject"
        submission.reject!(reviewer: current_user, review_note: note)
        render_json_dump(submission: submission_json(submission))
      else
        render_json_dump({ error: I18n.t("discourse_quiz.errors.invalid_status") }, status: 422)
      end
    end

    private

    def render_not_found
      render_json_dump({ error: I18n.t("discourse_quiz.errors.question_not_found") }, status: 404)
    end

    def normalize_status_filter(status)
      value = status.to_s.strip
      return nil if value.blank?

      %w[pending approved rejected].include?(value) ? value : nil
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
        reviewed_at: submission.reviewed_at,
        approved_question_id: submission.approved_question_id,
        created_at: submission.created_at,
      }
    end
  end
end
