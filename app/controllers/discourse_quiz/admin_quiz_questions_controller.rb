# frozen_string_literal: true

module DiscourseQuiz
  class AdminQuizQuestionsController < ::Admin::AdminController
    requires_plugin DiscourseQuiz::PLUGIN_NAME

    def index
      questions = QuizQuestion.order(created_at: :desc)

      if params[:category_name].present?
        questions = questions.where(category_name: params[:category_name])
      end

      render_json_dump(
        questions: serialize_data(questions.to_a, AdminQuizQuestionSerializer),
      )
    end

    def stats
      render_json_dump(
        total_questions: QuizQuestion.count,
        active_questions: QuizQuestion.where(active: true).count,
        total_attempts: QuizUserAttempt.count,
      )
    end

    def audit
      questions = QuizQuestion.where.not(source_topic_id: nil).order(:id)

      render_json_dump(
        questions: serialize_data(questions.to_a, AdminQuizQuestionSerializer),
        audited_at: Time.zone.now,
      )
    end

    def create
      question = QuizQuestion.new(question_params)
      if question.save
        render_serialized(question, AdminQuizQuestionSerializer, root: false)
      else
        render_json_error(question)
      end
    end

    def update
      question = QuizQuestion.find(params[:id])
      if question.update(question_params)
        render_serialized(question, AdminQuizQuestionSerializer, root: false)
      else
        render_json_error(question)
      end
    end

    def destroy
      question = QuizQuestion.find(params[:id])
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
