# frozen_string_literal: true

module DiscourseQuiz
  class QuizQuestionSubmissionsController < ::ApplicationController
    requires_plugin DiscourseQuiz::PLUGIN_NAME

    before_action :ensure_enabled
    before_action :ensure_logged_in

    def create
      submission =
        QuizQuestionSubmission.new(
          question_submission_params.merge(
            submitter_id: current_user.id,
            submitter_username: current_user.username,
          ),
        )

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
      params
        .require(:question_submission)
        .permit(
          :category_name,
          :question_text,
          :question_type,
          :correct_index,
          :explanation,
          options: [],
          correct_indices: [],
        )
    end
  end
end
