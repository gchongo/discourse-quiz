# frozen_string_literal: true

module DiscourseQuiz
  class QuizUserAttempt < ::ActiveRecord::Base
    self.table_name = "discourse_quiz_user_attempts"

    belongs_to :user
    belongs_to :question, class_name: "DiscourseQuiz::QuizQuestion", foreign_key: :question_id

    validates :user_id, presence: true
    validates :question_id, presence: true
    validates :is_correct, inclusion: { in: [true, false] }

    scope :awarded_today,
          ->(user_id) {
            where(user_id: user_id, is_correct: true, score_awarded: true).where(
              "created_at >= ?",
              Time.zone.now.beginning_of_day,
            )
          }

    def self.attempted_question_ids_for(user_id)
      where(user_id: user_id).distinct.pluck(:question_id)
    end

    def self.latest_wrong_question_ids_for(user_id)
      return [] unless table_ready?

      sql = <<~SQL
        SELECT latest.question_id
        FROM (
          SELECT DISTINCT ON (question_id) question_id, is_correct
          FROM discourse_quiz_user_attempts
          WHERE user_id = :user_id
          ORDER BY question_id, created_at DESC
        ) latest
        WHERE latest.is_correct = false
      SQL

      ActiveRecord::Base.connection.select_values(
        ActiveRecord::Base.sanitize_sql_array([sql, { user_id: user_id.to_i }]),
      ).map(&:to_i)
    end

    def self.today_counts_for(user_id)
      return { correct: 0, incorrect: 0 } unless table_ready?

      today =
        where(user_id: user_id).where(
          "created_at >= ?",
          Time.zone.now.beginning_of_day,
        )

      { correct: today.where(is_correct: true).count, incorrect: today.where(is_correct: false).count }
    end

    def self.lifetime_correct_count_for(user_id, question_ids: nil)
      return 0 unless table_ready?

      scope = where(user_id: user_id, is_correct: true)
      scope = scope.where(question_id: question_ids) if question_ids.present?
      scope.count
    end

    def self.lifetime_attempt_count_for(user_id, question_ids: nil)
      return 0 unless table_ready?

      scope = where(user_id: user_id)
      scope = scope.where(question_id: question_ids) if question_ids.present?
      scope.count
    end

    def self.never_correct_question_ids_for(user_id)
      return [] unless table_ready?

      attempted_question_ids_for(user_id) -
        where(user_id: user_id, is_correct: true).distinct.pluck(:question_id)
    end

    def self.recent_correct_question_ids_for(user_id, within: 30.minutes)
      return [] unless table_ready?

      where(user_id: user_id, is_correct: true).where(
        "created_at >= ?",
        Time.zone.now - within,
      ).distinct.pluck(:question_id)
    end

    def self.table_ready?
      ActiveRecord::Base.connection.table_exists?(:discourse_quiz_user_attempts)
    end

    def self.points_awarded_column?
      table_ready? && connection.column_exists?(table_name, :points_awarded)
    end
  end
end
