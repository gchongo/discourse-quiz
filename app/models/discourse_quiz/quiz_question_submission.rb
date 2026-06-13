# frozen_string_literal: true

module DiscourseQuiz
  class QuizQuestionSubmission < ::ActiveRecord::Base
    self.table_name = "discourse_quiz_question_submissions"

    STATUSES = %w[pending approved rejected].freeze

    validates :submitter_id, presence: true
    validates :submitter_username, presence: true
    validates :category_name, presence: true
    validates :question_text, presence: true
    validates :question_type, inclusion: { in: QuestionTypes::ALL }
    validates :status, inclusion: { in: STATUSES }
    validates :show_author_name, inclusion: { in: [true, false] }, if: :show_author_name_column?
    validate :options_must_be_array
    validate :correct_index_in_range
    validate :question_type_fields_valid

    before_validation :normalize_question_type_fields

    scope :pending, -> { where(status: "pending") }
    scope :recent_first, -> { order(created_at: :desc) }

    def approve!(reviewer:, review_note: nil)
      QuizQuestion.transaction do
        question =
          QuizQuestion.new(
            category_name: category_name,
            question_text: question_text,
            question_type: question_type,
            options: options,
            correct_index: correct_index,
            correct_indices: resolved_correct_indices,
            explanation: explanation,
            active: true,
            author_user_id: submitter_id,
            author_username: submitter_username,
            show_author_name: show_author_name_column? ? show_author_name : true,
          )
        question.save!

        update!(
          status: "approved",
          reviewer_id: reviewer.id,
          reviewed_at: Time.zone.now,
          review_note: review_note,
          approved_question_id: question.id,
        )

        question
      end
    end

    def reject!(reviewer:, review_note: nil)
      update!(
        status: "rejected",
        reviewer_id: reviewer.id,
        reviewed_at: Time.zone.now,
        review_note: review_note,
      )
    end

    def resolved_correct_indices
      return QuestionTypes.normalize_indices(correct_indices) if question_type == QuestionTypes::MULTIPLE_CHOICE

      [correct_index.to_i]
    end

    private

    def show_author_name_column?
      self.class.column_names.include?("show_author_name")
    end

    def normalize_question_type_fields
      self.question_type = question_type.presence || QuestionTypes::SINGLE_CHOICE

      case question_type
      when QuestionTypes::TRUE_FALSE
        self.options = QuestionTypes.true_false_options
        self.correct_index = correct_index.to_i.clamp(0, 1)
        self.correct_indices = []
      when QuestionTypes::MULTIPLE_CHOICE
        indices = QuestionTypes.normalize_indices(correct_indices)
        self.correct_indices = indices
        self.correct_index = indices.first || 0
      else
        self.question_type = QuestionTypes::SINGLE_CHOICE
        self.correct_indices = []
      end
    end

    def options_must_be_array
      unless options.is_a?(Array) && options.length > 0
        errors.add(:options, I18n.t("discourse_quiz.errors.invalid_options"))
      end

      if question_type == QuestionTypes::TRUE_FALSE && options.length != 2
        errors.add(:options, I18n.t("discourse_quiz.errors.invalid_true_false_options"))
      end

      if question_type == QuestionTypes::MULTIPLE_CHOICE && options.length < 2
        errors.add(:options, I18n.t("discourse_quiz.errors.invalid_multiple_choice_options"))
      end
    end

    def correct_index_in_range
      return if question_type == QuestionTypes::MULTIPLE_CHOICE
      return unless options.is_a?(Array) && correct_index.is_a?(Integer)

      unless correct_index >= 0 && correct_index < options.length
        errors.add(:correct_index, I18n.t("discourse_quiz.errors.invalid_correct_index"))
      end
    end

    def question_type_fields_valid
      return unless question_type == QuestionTypes::MULTIPLE_CHOICE

      indices = QuestionTypes.normalize_indices(correct_indices)
      if indices.blank?
        errors.add(:correct_indices, I18n.t("discourse_quiz.errors.invalid_correct_indices"))
        return
      end

      indices.each do |index|
        unless options.is_a?(Array) && index >= 0 && index < options.length
          errors.add(:correct_indices, I18n.t("discourse_quiz.errors.invalid_correct_indices"))
          return
        end
      end
    end
  end
end
