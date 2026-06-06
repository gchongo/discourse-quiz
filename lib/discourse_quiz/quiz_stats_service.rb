# frozen_string_literal: true

module DiscourseQuiz
  class QuizStatsService
    def initialize(user)
      @user = user
    end

    def summary(category_names: [])
      return nil unless @user

      scope = scoped_questions(category_names)
      scope_ids = scope.pluck(:id)
      attempted_ids = QuizUserAttempt.attempted_question_ids_for(@user.id)
      never_correct_ids = QuizUserAttempt.never_correct_question_ids_for(@user.id)
      wrong_ids = QuizUserAttempt.latest_wrong_question_ids_for(@user.id)
      today = QuizUserAttempt.today_counts_for(@user.id)

      lifetime_correct =
        QuizUserAttempt.lifetime_correct_count_for(@user.id, question_ids: scope_ids)
      lifetime_attempts =
        QuizUserAttempt.lifetime_attempt_count_for(@user.id, question_ids: scope_ids)

      {
        lifetime_correct: lifetime_correct,
        lifetime_attempts: lifetime_attempts,
        accuracy_rate: accuracy_rate(lifetime_correct, lifetime_attempts),
        wrong_questions: (never_correct_ids & scope_ids).size,
        today_correct: today[:correct],
        today_incorrect: today[:incorrect],
        wrong_pending: (wrong_ids & scope_ids).size,
        unseen_pending: (scope_ids - attempted_ids).size,
        questions_in_scope: scope_ids.size,
      }
    end

    private

    def scoped_questions(category_names)
      names = normalize_category_names(category_names)
      scope = QuizQuestion.active
      scope = scope.where(category_name: names) if names.present?
      scope
    end

    def normalize_category_names(category_names)
      Array(category_names).map(&:to_s).map(&:strip).reject(&:blank?).uniq
    end

    def accuracy_rate(lifetime_correct, lifetime_attempts)
      return nil if lifetime_attempts.zero?

      ((lifetime_correct.to_f / lifetime_attempts) * 100).round(1)
    end
  end
end
