# frozen_string_literal: true

module DiscourseQuiz
  class QuizQuestion < ::ActiveRecord::Base
    self.table_name = "discourse_quiz_questions"

    validates :category_name, presence: true
    validates :question_text, presence: true
    validates :options, presence: true
    validates :question_type, inclusion: { in: QuestionTypes::ALL }

    validate :correct_index_in_range
    validate :options_must_be_array
    validate :question_type_fields_valid

    before_validation :normalize_question_type_fields

    scope :active, -> { where(active: true) }
    scope :by_category, ->(name) { where(category_name: name) if name.present? }
    scope :search_query,
          ->(query) {
            if query.present?
              sanitized = ActiveRecord::Base.sanitize_sql_like(query.to_s.strip)
              pattern = "%#{sanitized}%"
              where("question_text ILIKE ? OR category_name ILIKE ?", pattern, pattern)
            end
          }

    def self.position_column?
      connection.column_exists?(table_name, :position)
    end

    def self.question_type_column?
      connection.column_exists?(table_name, :question_type)
    end

    def self.ordered_for_admin
      if position_column?
        order(position: :asc, id: :asc)
      else
        order(id: :asc)
      end
    end

    def self.category_names
      distinct.order(:category_name).pluck(:category_name)
    end

    def self.active_category_names
      active.distinct.order(:category_name).pluck(:category_name)
    end

    def self.available_category_names(allowed: [])
      names = active_category_names
      allowlist = Array(allowed).map(&:to_s).map(&:strip).reject(&:blank?)
      return names if allowlist.blank?

      names.select { |name| allowlist.include?(name) }
    end

    def self.pick_random(category_names: [])
      scope = active
      names = Array(category_names).map(&:to_s).map(&:strip).reject(&:blank?)
      scope = scope.where(category_name: names) if names.present?
      scope.order(Arel.sql("RANDOM()")).first
    end

    def resolved_question_type
      return QuestionTypes::SINGLE_CHOICE unless self.class.question_type_column?

      question_type.presence || QuestionTypes::SINGLE_CHOICE
    end

    def true_false?
      resolved_question_type == QuestionTypes::TRUE_FALSE
    end

    def multiple_choice?
      resolved_question_type == QuestionTypes::MULTIPLE_CHOICE
    end

    def resolved_correct_indices
      return QuestionTypes.normalize_indices(correct_indices) if multiple_choice?

      [correct_index.to_i]
    end

    def graded_correct?(answer_index: nil, answer_indices: nil)
      if multiple_choice?
        submitted = QuestionTypes.normalize_indices(answer_indices)
        return false if submitted.blank?

        submitted == resolved_correct_indices
      else
        answer_index.to_i == correct_index.to_i
      end
    end

    def correct_option_labels
      resolved_correct_indices.map { |index| options[index] }.compact
    end

    private

    def normalize_question_type_fields
      unless self.class.question_type_column?
        self.correct_index ||= 0
        return
      end

      self.question_type = resolved_question_type

      case resolved_question_type
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

    def question_type_fields_valid
      return unless self.class.question_type_column?

      if multiple_choice?
        indices = resolved_correct_indices
        if indices.blank?
          errors.add(:correct_indices, I18n.t("discourse_quiz.errors.invalid_correct_indices"))
          return
        end

        indices.each do |index|
          unless index_in_options_range?(index)
            errors.add(:correct_indices, I18n.t("discourse_quiz.errors.invalid_correct_indices"))
            return
          end
        end
      elsif !index_in_options_range?(correct_index.to_i)
        errors.add(:correct_index, I18n.t("discourse_quiz.errors.invalid_correct_index"))
      end
    end

    def correct_index_in_range
      return if multiple_choice?
      return unless options.is_a?(Array) && correct_index.is_a?(Integer)

      unless index_in_options_range?(correct_index)
        errors.add(:correct_index, I18n.t("discourse_quiz.errors.invalid_correct_index"))
      end
    end

    def options_must_be_array
      unless options.is_a?(Array) && options.length > 0
        errors.add(:options, I18n.t("discourse_quiz.errors.invalid_options"))
      end

      if true_false? && options.length != 2
        errors.add(:options, I18n.t("discourse_quiz.errors.invalid_true_false_options"))
      end

      if multiple_choice? && options.length < 2
        errors.add(:options, I18n.t("discourse_quiz.errors.invalid_multiple_choice_options"))
      end
    end

    def index_in_options_range?(index)
      options.is_a?(Array) && index >= 0 && index < options.length
    end
  end
end
