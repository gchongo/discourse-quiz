# frozen_string_literal: true

module DiscourseQuiz
  class QuizQuestionPicker
    def initialize(user)
      @user = user
    end

    def pick_next
      if @user
        pick_for_logged_in_user
      else
        pick_random_active
      end
    end

    private

    def pick_for_logged_in_user
      # Prefer questions the user hasn't answered correctly yet
      answered_correctly_ids = QuizUserAttempt.where(user_id: @user.id, is_correct: true)
                                              .pluck(:question_id)

      question = QuizQuestion.where(active: true)
                             .where.not(id: answered_correctly_ids)
                             .order("RANDOM()")
                             .first

      # If all questions answered correctly, just pick a random active one
      question ||= pick_random_active
      question
    end

    def pick_random_active
      QuizQuestion.where(active: true).order("RANDOM()").first
    end
  end
end
