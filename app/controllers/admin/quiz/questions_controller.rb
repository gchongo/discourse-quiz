# frozen_string_literal: true

module Admin::Quiz
  class QuestionsController < Admin::AdminController
    requires_plugin DiscourseQuiz::PLUGIN_NAME

    rescue_from StandardError do |e|
      raise if e.is_a?(ApplicationController::PluginDisabled)
      raise if e.is_a?(ActiveRecord::RecordNotFound)

      Rails.logger.error(
        "[DiscourseQuiz] #{action_name} failed: #{e.class}: #{e.message}\n#{e.backtrace.first(8).join("\n")}",
      )
      render_json_dump({ error: e.class.name, message: e.message }, status: 500)
    end

    def index
      questions = DiscourseQuiz::QuizQuestion.order(created_at: :desc)

      if params[:category_name].present?
        questions = questions.where(category_name: params[:category_name])
      end

      render_json_dump(
        questions: serialize_data(questions.to_a, AdminQuizQuestionSerializer),
      )
    end

    def stats
      render_json_dump(
        total_questions: DiscourseQuiz::QuizQuestion.count,
        active_questions: DiscourseQuiz::QuizQuestion.where(active: true).count,
        total_attempts: DiscourseQuiz::QuizUserAttempt.count,
      )
    end

    def create
      question = DiscourseQuiz::QuizQuestion.new(question_params)
      if question.save
        render_serialized(question, AdminQuizQuestionSerializer, root: false)
      else
        render_json_error(question)
      end
    end

    def update
      question = DiscourseQuiz::QuizQuestion.find(params[:id])
      if question.update(question_params)
        render_serialized(question, AdminQuizQuestionSerializer, root: false)
      else
        render_json_error(question)
      end
    end

    def destroy
      question = DiscourseQuiz::QuizQuestion.find(params[:id])
      question.destroy!
      head :no_content
    end

    private

    def question_params
      permitted =
        params.require(:question).permit(
          :category_name,
          :question_text,
          :correct_index,
          :explanation,
          :source_topic_id,
          :active,
          options: [],
        )

      permitted[:source_topic_id] = nil if permitted[:source_topic_id].blank?
      permitted
    end
  end
end
