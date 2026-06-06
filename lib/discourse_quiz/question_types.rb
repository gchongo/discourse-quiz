# frozen_string_literal: true

module DiscourseQuiz
  module QuestionTypes
    SINGLE_CHOICE = "single_choice"
    TRUE_FALSE = "true_false"
    MULTIPLE_CHOICE = "multiple_choice"

    ALL = [SINGLE_CHOICE, TRUE_FALSE, MULTIPLE_CHOICE].freeze

    def self.true_false_options
      [
        I18n.t("discourse_quiz.true_false.true"),
        I18n.t("discourse_quiz.true_false.false"),
      ]
    end

    def self.normalize_indices(values)
      Array(values).map(&:to_i).reject(&:negative?).uniq.sort
    end
  end
end
