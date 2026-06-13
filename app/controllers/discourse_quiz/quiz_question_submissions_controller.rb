# frozen_string_literal: true

module DiscourseQuiz
  class QuizQuestionSubmissionsController < ::ApplicationController
    requires_plugin DiscourseQuiz::PLUGIN_NAME

    before_action :ensure_enabled
    before_action :ensure_logged_in

    def create
      attrs = question_submission_params.to_h.symbolize_keys
      attrs[:status] = "pending"
      attrs[:show_author_name] = true if attrs[:show_author_name].nil?
      attrs[:submitter_id] = current_user.id
      attrs[:submitter_username] = current_user.username

      submission = QuizQuestionSubmission.new(attrs)

      if submission.save
        render_json_dump(
          {
            status: "ok",
            submission_id: submission.id,
          },
        )
      else
        render_json_dump({ errors: submission.errors.full_messages }, status: 422)
      end
    end

    private

    def ensure_enabled
      raise Discourse::NotFound unless SiteSetting.quiz_plugin_enabled
    end

    def ensure_logged_in
      raise Discourse::InvalidAccess unless current_user
    end

    def question_submission_params
      permitted =
        params
        .require(:question_submission)
        .permit(
          :category_name,
          :question_text,
          :question_type,
          :correct_index,
          :explanation,
          :show_author_name,
          options: [],
          correct_indices: [],
        )

      permitted.delete(:show_author_name) unless QuizQuestionSubmission.column_names.include?("show_author_name")
      permitted
    end
  end
end
