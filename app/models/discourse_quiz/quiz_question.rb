# frozen_string_literal: true

module DiscourseQuiz
  class QuizQuestion < ::ActiveRecord::Base
    self.table_name = "discourse_quiz_questions"

    validates :category_name, presence: true
    validates :question_text, presence: true
    validates :options, presence: true
    validates :correct_index, presence: true

    validate :correct_index_in_range
    validate :options_must_be_array

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

    private

    def correct_index_in_range
      return unless options.is_a?(Array) && correct_index.is_a?(Integer)

      if correct_index < 0 || correct_index >= options.length
        errors.add(:correct_index, I18n.t("discourse_quiz.errors.invalid_correct_index"))
      end
    end

    def options_must_be_array
      unless options.is_a?(Array) && options.length > 0
        errors.add(:options, I18n.t("discourse_quiz.errors.invalid_options"))
      end
    end
  end
end
