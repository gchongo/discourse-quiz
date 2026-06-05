# frozen_string_literal: true

module DiscourseGamifiedQuiz
  class QuizQuestion < ActiveRecord::Base
    self.table_name = "discourse_quiz_questions"

    validates :category_name, presence: true
    validates :question_text, presence: true
    validates :options, presence: true
    validates :correct_index, presence: true

    validate :options_must_be_non_empty_array
    validate :correct_index_within_bounds

    has_many :user_attempts, class_name: "DiscourseGamifiedQuiz::QuizUserAttempt", foreign_key: "question_id", dependent: :destroy

    scope :active, -> { where(active: true) }
    scope :with_audit_errors, -> { where("validation_errors != '[]'::jsonb") }

    def audit_status
      validation_errors.presence || []
    end

    private

    def options_must_be_non_empty_array
      unless options.is_a?(Array) && options.present?
        errors.add(:options, I18n.t("errors.messages.invalid"))
      end
    end

    def correct_index_within_bounds
      return unless options.is_a?(Array) && correct_index.is_a?(Integer)

      unless correct_index >= 0 && correct_index < options.length
        errors.add(:correct_index, I18n.t("errors.messages.invalid"))
      end
    end
  end
end
