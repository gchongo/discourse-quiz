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
      answered_correctly_ids =
        QuizUserAttempt.where(user_id: @user.id, is_correct: true).pluck(:question_id)

      question =
        active_questions_scope
          .where.not(id: answered_correctly_ids)
          .order(Arel.sql("RANDOM()"))
          .first

      question || pick_random_active
    end

    def pick_random_active
      active_questions_scope.order(Arel.sql("RANDOM()")).first
    end

    def active_questions_scope
      scope = QuizQuestion.where(active: true)
      category_names = enabled_category_names
      scope = scope.where(category_name: category_names) if category_names.present?
      scope
    end

    def enabled_category_names
      setting = SiteSetting.quiz_categories.to_s
      return [] if setting.blank?

      category_ids = setting.split(",").map(&:strip).map(&:to_i).reject(&:zero?)
      return [] if category_ids.empty?

      Category.where(id: category_ids).pluck(:name)
    end
  end
end
