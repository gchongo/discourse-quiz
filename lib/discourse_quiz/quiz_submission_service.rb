# frozen_string_literal: true

module DiscourseQuiz
  class QuizSubmissionService
    attr_reader :status_code, :failed

    def initialize(user, question, answer_index)
      @user = user
      @question = question
      @answer_index = answer_index
      @status_code = 200
      @failed = false
    end

    def submit
      unless valid_answer_index?
        @status_code = 422
        @failed = true
        return { error: I18n.t("discourse_quiz.errors.invalid_answer_index") }
      end

      is_correct = @question.correct_index == @answer_index.to_i
      points_awarded = 0

      if @user && attempts_table_ready?
        attempt =
          QuizUserAttempt.create!(
            user_id: @user.id,
            question_id: @question.id,
            answer_index: @answer_index.to_i,
            is_correct: is_correct,
            created_at: Time.zone.now,
          )

        if is_correct
          QuizPointsService.award_points(@user, @question, attempt)
          points_awarded = SiteSetting.quiz_points_per_question if attempt.reload.score_awarded
        end
      end

      {
        correct: is_correct,
        explanation: @question.explanation,
        correct_index: @question.correct_index,
        correct_option: @question.options[@question.correct_index],
        points_awarded: points_awarded,
      }
    end

    def failed?
      @failed
    end

    private

    def valid_answer_index?
      return false if @answer_index.nil?

      index = @answer_index.to_i
      options = @question.options
      options.is_a?(Array) && index >= 0 && index < options.length
    end

    def attempts_table_ready?
      ActiveRecord::Base.connection.table_exists?(:discourse_quiz_user_attempts)
    end
  end
end
