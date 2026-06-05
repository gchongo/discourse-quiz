# frozen_string_literal: true

module DiscourseQuiz
  class QuizQuestion < ::ActiveRecord::Base
    self.table_name = "discourse_quiz_questions"

    validates :category_name, presence: true
    validates :question_text, presence: true
    validates :options, presence: true
    validates :correct_index, presence: true

    validate :correct_index_range
    validate :options_is_array

    has_many :attempts,
             class_name: "DiscourseQuiz::QuizUserAttempt",
             foreign_key: "question_id",
             dependent: :destroy

    scope :active, -> { where(active: true) }

    private

    def correct_index_range
      return unless options.is_a?(Array) && correct_index.is_a?(Integer)

      if correct_index < 0 || correct_index >= options.length
        errors.add(:correct_index, I18n.t("gamified_quiz.errors.invalid_correct_index"))
      end
    end

    def options_is_array
      unless options.is_a?(Array) && options.length > 0
        errors.add(:options, I18n.t("gamified_quiz.errors.invalid_options"))
      end
    end
  end
end
