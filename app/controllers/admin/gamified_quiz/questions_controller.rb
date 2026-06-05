# frozen_string_literal: true

module Admin::GamifiedQuiz
  class QuestionsController < Admin::AdminController
    def index
      questions = DiscourseGamifiedQuiz::QuizQuestion.order(created_at: :desc)
      
      if params[:category_name].present?
        questions = questions.where(category_name: params[:category_name])
      end

      render_serialized(questions, Admin::GamifiedQuiz::QuizQuestionSerializer)
    end

    def stats
      render json: {
        total_questions: DiscourseGamifiedQuiz::QuizQuestion.count,
        active_questions: DiscourseGamifiedQuiz::QuizQuestion.where(active: true).count,
        total_attempts: DiscourseGamifiedQuiz::QuizUserAttempt.count
      }
    end

    def create
      question = DiscourseGamifiedQuiz::QuizQuestion.new(question_params)
      if question.save
        render_serialized(question, Admin::GamifiedQuiz::QuizQuestionSerializer)
      else
        render_json_error(question)
      end
    end

    def update
      question = DiscourseGamifiedQuiz::QuizQuestion.find(params[:id])
      if question.update(question_params)
        render_serialized(question, Admin::GamifiedQuiz::QuizQuestionSerializer)
      else
        render_json_error(question)
      end
    end

    def destroy
      question = DiscourseGamifiedQuiz::QuizQuestion.find(params[:id])
      question.destroy
      render json: success_json
    end

    private

    def question_params
      params.require(:question).permit(
        :category_name,
        :question_text,
        :correct_index,
        :explanation,
        :source_topic_id,
        :active,
        options: []
      )
    end
  end
end
