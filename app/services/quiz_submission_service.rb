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
        return { error: I18n.t("gamified_quiz.errors.invalid_answer_index") }
      end

      is_correct = @question.correct_index == @answer_index.to_i

      if @user
        attempt = QuizUserAttempt.create!(
          user_id: @user.id,
          question_id: @question.id,
          is_correct: is_correct,
          created_at: Time.zone.now,
        )

        QuizPointsService.award_points(@user, @question, attempt) if is_correct
      end

      result = { correct: is_correct }

      if is_correct
        result[:explanation] = formatted_explanation
      end

      result
    end

    def failed?
      @failed
    end

    private

    def valid_answer_index?
      return false unless @answer_index.present?

      index = @answer_index.to_i
      options = @question.options
      options.is_a?(Array) && index >= 0 && index < options.length
    end

    def formatted_explanation
      if @user
        @question.explanation
      else
        mask_text(@question.explanation)
      end
    end

    def mask_text(text)
      return nil if text.blank?

      words = text.split
      visible_count = (words.length * 0.2).ceil
      visible_count = 5 if visible_count < 5 && words.length > 5

      masked = words[0...visible_count].join(" ")
      masked += " ... [#{I18n.t('gamified_quiz.guest_explanation_masked_suffix')}]"
      masked
    end
  end
end
