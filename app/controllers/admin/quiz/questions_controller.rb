# frozen_string_literal: true

module Admin::Quiz
  class QuestionsController < Admin::AdminController
    def index
      questions = DiscourseQuiz::QuizQuestion.order(created_at: :desc)

      if params[:category_name].present?
        questions = questions.where(category_name: params[:category_name])
      end

      render json: {
        questions: serialize_data(questions, Admin::Quiz::QuizQuestionSerializer),
      }
    end

    def stats
      render json: {
        total_questions: DiscourseQuiz::QuizQuestion.count,
        active_questions: DiscourseQuiz::QuizQuestion.where(active: true).count,
        total_attempts: DiscourseQuiz::QuizUserAttempt.count,
      }
    end

    def create
      question = DiscourseQuiz::QuizQuestion.new(question_params)
      if question.save
        render_serialized(question, Admin::Quiz::QuizQuestionSerializer, root: false)
      else
        render_json_error(question)
      end
    end

    def update
      question = DiscourseQuiz::QuizQuestion.find(params[:id])
      if question.update(question_params)
        render_serialized(question, Admin::Quiz::QuizQuestionSerializer, root: false)
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
      params.require(:question).permit(
        :category_name,
        :question_text,
        :correct_index,
        :explanation,
        :source_topic_id,
        :active,
        options: [],
      )
    end
  end
end
