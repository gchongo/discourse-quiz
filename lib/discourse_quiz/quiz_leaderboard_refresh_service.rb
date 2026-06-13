# frozen_string_literal: true

module DiscourseQuiz
  class QuizLeaderboardRefreshService
    PERIODS = %w[all yearly quarterly monthly weekly daily].freeze

    ACTIVE_USER_SQL = <<~SQL.squish
      u.active = TRUE
      AND (u.suspended_till IS NULL OR u.suspended_till < :now)
      AND u.staged = FALSE
    SQL

    def self.refresh_all!
      return unless tables_ready?

      now = Time.zone.now
      QuizLeaderboardStat.delete_all
      if period_columns_ready?
        insert_period_rows!(now)
      else
        insert_global_rows!(now)
        insert_category_rows!(now)
      end
      true
    end

    def self.refresh_user!(user_id)
      return unless tables_ready?

      user_id = user_id.to_i
      return if user_id <= 0

      now = Time.zone.now
      QuizLeaderboardStat.where(user_id: user_id).delete_all

      if period_columns_ready?
        insert_period_rows!(now, user_id: user_id)
      else
        insert_global_rows!(now, user_id: user_id)
        insert_category_rows!(now, user_id: user_id)
      end
      true
    end

    def self.tables_ready?
      QuizUserAttempt.table_ready? && QuizLeaderboardStat.table_ready?
    end

    def self.period_columns_ready?
      ActiveRecord::Base.connection.column_exists?(:discourse_quiz_leaderboard_stats, :period_type) &&
        ActiveRecord::Base.connection.column_exists?(:discourse_quiz_leaderboard_stats, :period_start)
    end

    def self.insert_period_rows!(now, user_id: nil)
      PERIODS.each do |period_type|
        period_start = QuizLeaderboardStat.period_start_for(period_type, now: now)
        window_start = period_type == "all" ? nil : period_start.beginning_of_day

        insert_global_rows_for_period!(
          now,
          period_type,
          period_start,
          window_start: window_start,
          user_id: user_id,
        )
        insert_category_rows_for_period!(
          now,
          period_type,
          period_start,
          window_start: window_start,
          user_id: user_id,
        )
      end
    end

    def self.insert_global_rows!(now, user_id: nil)
      user_filter = user_id ? "AND a.user_id = :user_id" : ""

      DB.exec(
        <<~SQL,
          INSERT INTO discourse_quiz_leaderboard_stats
            (user_id, category_name, questions_attempted, questions_correct, accuracy_rate, updated_at)
          SELECT
            stats.user_id,
            '',
            stats.questions_attempted,
            stats.questions_correct,
            CASE
              WHEN stats.questions_attempted > 0
              THEN ROUND(100.0 * stats.questions_correct / stats.questions_attempted, 1)
              ELSE NULL
            END,
            :now
          FROM (
            SELECT
              a.user_id,
              COUNT(DISTINCT a.question_id) AS questions_attempted,
              COUNT(DISTINCT CASE WHEN a.is_correct THEN a.question_id END) AS questions_correct
            FROM discourse_quiz_user_attempts a
            INNER JOIN users u ON u.id = a.user_id
            INNER JOIN discourse_quiz_questions q ON q.id = a.question_id AND q.active = TRUE
            WHERE #{ACTIVE_USER_SQL}
              #{user_filter}
            GROUP BY a.user_id
          ) stats
        SQL
        now: now,
        user_id: user_id,
      )
    end

    def self.insert_global_rows_for_period!(now, period_type, period_start, window_start:, user_id: nil)
      user_filter = user_id ? "AND a.user_id = :user_id" : ""
      window_filter = window_start ? "AND a.created_at >= :window_start" : ""

      DB.exec(
        <<~SQL,
          INSERT INTO discourse_quiz_leaderboard_stats
            (
              user_id,
              category_name,
              period_type,
              period_start,
              questions_attempted,
              questions_correct,
              accuracy_rate,
              updated_at
            )
          SELECT
            stats.user_id,
            '',
            :period_type,
            :period_start,
            stats.questions_attempted,
            stats.questions_correct,
            CASE
              WHEN stats.questions_attempted > 0
              THEN ROUND(100.0 * stats.questions_correct / stats.questions_attempted, 1)
              ELSE NULL
            END,
            :now
          FROM (
            SELECT
              a.user_id,
              COUNT(DISTINCT a.question_id) AS questions_attempted,
              COUNT(DISTINCT CASE WHEN a.is_correct THEN a.question_id END) AS questions_correct
            FROM discourse_quiz_user_attempts a
            INNER JOIN users u ON u.id = a.user_id
            INNER JOIN discourse_quiz_questions q ON q.id = a.question_id AND q.active = TRUE
            WHERE #{ACTIVE_USER_SQL}
              #{window_filter}
              #{user_filter}
            GROUP BY a.user_id
          ) stats
        SQL
        now: now,
        user_id: user_id,
        period_type: period_type,
        period_start: period_start,
        window_start: window_start,
      )
    end

    def self.insert_category_rows!(now, user_id: nil)
      user_filter = user_id ? "AND a.user_id = :user_id" : ""

      DB.exec(
        <<~SQL,
          INSERT INTO discourse_quiz_leaderboard_stats
            (user_id, category_name, questions_attempted, questions_correct, accuracy_rate, updated_at)
          SELECT
            stats.user_id,
            stats.category_name,
            stats.questions_attempted,
            stats.questions_correct,
            CASE
              WHEN stats.questions_attempted > 0
              THEN ROUND(100.0 * stats.questions_correct / stats.questions_attempted, 1)
              ELSE NULL
            END,
            :now
          FROM (
            SELECT
              a.user_id,
              q.category_name,
              COUNT(DISTINCT a.question_id) AS questions_attempted,
              COUNT(DISTINCT CASE WHEN a.is_correct THEN a.question_id END) AS questions_correct
            FROM discourse_quiz_user_attempts a
            INNER JOIN users u ON u.id = a.user_id
            INNER JOIN discourse_quiz_questions q ON q.id = a.question_id AND q.active = TRUE
            WHERE #{ACTIVE_USER_SQL}
              #{user_filter}
            GROUP BY a.user_id, q.category_name
          ) stats
        SQL
        now: now,
        user_id: user_id,
      )
    end

    def self.insert_category_rows_for_period!(now, period_type, period_start, window_start:, user_id: nil)
      user_filter = user_id ? "AND a.user_id = :user_id" : ""
      window_filter = window_start ? "AND a.created_at >= :window_start" : ""

      DB.exec(
        <<~SQL,
          INSERT INTO discourse_quiz_leaderboard_stats
            (
              user_id,
              category_name,
              period_type,
              period_start,
              questions_attempted,
              questions_correct,
              accuracy_rate,
              updated_at
            )
          SELECT
            stats.user_id,
            stats.category_name,
            :period_type,
            :period_start,
            stats.questions_attempted,
            stats.questions_correct,
            CASE
              WHEN stats.questions_attempted > 0
              THEN ROUND(100.0 * stats.questions_correct / stats.questions_attempted, 1)
              ELSE NULL
            END,
            :now
          FROM (
            SELECT
              a.user_id,
              q.category_name,
              COUNT(DISTINCT a.question_id) AS questions_attempted,
              COUNT(DISTINCT CASE WHEN a.is_correct THEN a.question_id END) AS questions_correct
            FROM discourse_quiz_user_attempts a
            INNER JOIN users u ON u.id = a.user_id
            INNER JOIN discourse_quiz_questions q ON q.id = a.question_id AND q.active = TRUE
            WHERE #{ACTIVE_USER_SQL}
              #{window_filter}
              #{user_filter}
            GROUP BY a.user_id, q.category_name
          ) stats
        SQL
        now: now,
        user_id: user_id,
        period_type: period_type,
        period_start: period_start,
        window_start: window_start,
      )
    end
  end
end
