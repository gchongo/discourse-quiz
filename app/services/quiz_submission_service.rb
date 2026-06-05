# frozen_string_literal: true

module DiscourseGamifiedQuiz
  class QuizSubmissionService
    def initialize(user, question, answer_index)
      @user = user
      @question = question
      @answer_index = answer_index.to_i
    end

    def submit
      is_correct = @question.correct_index == @answer_index

      # Record attempt
      if @user
        attempt = QuizUserAttempt.create!(
          user_id: @user.id,
          question_id: @question.id,
          is_correct: is_correct,
          created_at: Time.zone.now
        )

        if is_correct
          QuizPointsService.award_points(@user, @question, attempt)
        end
      end

      result = {
        correct: is_correct
      }

      if is_correct
        result[:explanation] = formatted_explanation
      end

      result
    end

    private

    def formatted_explanation
      if @user
        @question.explanation
      else
        # Mask explanation for guests
        mask_text(@question.explanation)
      end
    end

    def mask_text(text)
      return nil if text.blank?
      # Simple masking: show first 20% of words, hide rest
      words = text.split
      visible_count = (words.length * 0.2).ceil
      visible_count = 5 if visible_count < 5 && words.length > 5
      
      masked = words[0...visible_count].join(" ")
      masked += " ... [Log in to see full explanation]"
      masked
    end
  end
end
