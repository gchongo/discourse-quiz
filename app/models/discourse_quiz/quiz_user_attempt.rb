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

    def self.table_ready?
      ActiveRecord::Base.connection.table_exists?(:discourse_quiz_user_attempts)
    end
  end
end
