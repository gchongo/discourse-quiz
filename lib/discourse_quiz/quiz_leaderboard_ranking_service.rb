# frozen_string_literal: true

module DiscourseQuiz
  class QuizLeaderboardRankingService
    METRICS = %w[volume accuracy].freeze

    def self.ranking(metric:, period: "all", page: 1, per_page: nil, for_user_id: nil)
      return empty_payload(metric, page, per_page) unless QuizLeaderboardStat.table_ready?

      metric = METRICS.include?(metric.to_s) ? metric.to_s : "volume"
      period = QuizLeaderboardStat.normalize_period(period)
      period_start = QuizLeaderboardStat.period_start_for(period)
      page = [page.to_i, 1].max
      per_page = per_page || SiteSetting.quiz_leaderboard_user_limit.to_i
      per_page = 50 if per_page <= 0
      per_page = [per_page, 100].min
      min_attempts = SiteSetting.quiz_leaderboard_min_attempts.to_i

      ensure_cached!

      scope = ranked_scope(metric, min_attempts, period: period, period_start: period_start)
      total = scope.count
      rows = scope.offset((page - 1) * per_page).limit(per_page).to_a
      users = load_users(rows.map(&:user_id))
      start_rank = (page - 1) * per_page

      {
        metric: metric,
        period: period,
        period_start: period_start,
        page: page,
        per_page: per_page,
        total: total,
        min_attempts: min_attempts,
        users:
          rows.map.with_index(1) do |row, index|
            user_json(row, users, start_rank + index, metric: metric)
          end,
        personal: personal_entry(metric, min_attempts, for_user_id, period: period, period_start: period_start),
        refreshed_at: period_scope(QuizLeaderboardStat.global_rows, period: period, period_start: period_start).maximum(:updated_at),
      }
    end

    def self.user_categories(user, period: "all")
      return nil unless user && QuizLeaderboardStat.table_ready?

      ensure_cached!

      period = QuizLeaderboardStat.normalize_period(period)
      period_start = QuizLeaderboardStat.period_start_for(period)

      global =
        period_scope(QuizLeaderboardStat.global_rows, period: period, period_start: period_start).find_by(user_id: user.id)

      categories =
        period_scope(
          QuizLeaderboardStat
            .category_rows,
          period: period,
          period_start: period_start,
        )
          .where(user_id: user.id)
          .where("questions_attempted > 0")
          .order(questions_attempted: :desc, category_name: :asc)

      {
        period: period,
        period_start: period_start,
        user: user_json_from_user(user, global),
        categories:
          categories.map do |row|
            {
              category_name: row.category_name,
              questions_attempted: row.questions_attempted,
              questions_correct: row.questions_correct,
              accuracy_rate: row.accuracy_rate,
            }
          end,
      }
    end

    def self.ensure_cached!
      return if QuizLeaderboardStat.global_rows.exists?

      QuizLeaderboardRefreshService.refresh_all!
    end

    def self.ranked_scope(metric, min_attempts, period:, period_start:)
      scope =
        period_scope(
          QuizLeaderboardStat
            .global_rows,
          period: period,
          period_start: period_start,
        )
          .joins(:user)
          .merge(User.real.activated)
          .where(
            "users.suspended_till IS NULL OR users.suspended_till < ?",
            Time.zone.now,
          )

      if metric == "accuracy"
        scope
          .where("discourse_quiz_leaderboard_stats.questions_attempted >= ?", min_attempts)
          .order(
            Arel.sql("discourse_quiz_leaderboard_stats.accuracy_rate DESC NULLS LAST"),
            questions_attempted: :desc,
            user_id: :asc,
          )
      else
        scope
          .where("discourse_quiz_leaderboard_stats.questions_attempted > 0")
          .order(questions_attempted: :desc, accuracy_rate: :desc, user_id: :asc)
      end
    end

    def self.personal_entry(metric, min_attempts, user_id, period:, period_start:)
      return nil unless user_id

      row = period_scope(QuizLeaderboardStat.global_rows, period: period, period_start: period_start).find_by(user_id: user_id)
      return nil unless row

      if metric == "accuracy" && row.questions_attempted.to_i < min_attempts
        return ineligible_personal_json(row, min_attempts)
      end

      scope = ranked_scope(metric, min_attempts, period: period, period_start: period_start)
      position =
        scope
          .where(
            metric == "accuracy" ? accuracy_rank_clause(row) : volume_rank_clause(row),
          )
          .count + 1

      user = User.find_by(id: user_id)
      return nil unless user

      user_json(row, { user_id => user }, position, metric: metric)
    end

    def self.volume_rank_clause(row)
      [
        "discourse_quiz_leaderboard_stats.questions_attempted > ? OR " \
          "(discourse_quiz_leaderboard_stats.questions_attempted = ? AND " \
          "(discourse_quiz_leaderboard_stats.accuracy_rate > ? OR " \
          "(discourse_quiz_leaderboard_stats.accuracy_rate = ? AND discourse_quiz_leaderboard_stats.user_id < ?)))",
        row.questions_attempted,
        row.questions_attempted,
        row.accuracy_rate.to_f,
        row.accuracy_rate.to_f,
        row.user_id,
      ]
    end

    def self.accuracy_rank_clause(row)
      [
        "discourse_quiz_leaderboard_stats.accuracy_rate > ? OR " \
          "(discourse_quiz_leaderboard_stats.accuracy_rate = ? AND discourse_quiz_leaderboard_stats.questions_attempted > ?) OR " \
          "(discourse_quiz_leaderboard_stats.accuracy_rate = ? AND discourse_quiz_leaderboard_stats.questions_attempted = ? AND discourse_quiz_leaderboard_stats.user_id < ?)",
        row.accuracy_rate.to_f,
        row.accuracy_rate.to_f,
        row.questions_attempted,
        row.accuracy_rate.to_f,
        row.questions_attempted,
        row.user_id,
      ]
    end

    def self.ineligible_personal_json(row, min_attempts)
      {
        position: nil,
        id: row.user_id,
        username: User.find_by(id: row.user_id)&.username,
        questions_attempted: row.questions_attempted,
        questions_correct: row.questions_correct,
        accuracy_rate: row.accuracy_rate,
        value: row.accuracy_rate,
        ineligible: true,
        min_attempts: min_attempts,
      }
    end

    def self.load_users(user_ids)
      User.where(id: user_ids.uniq).index_by(&:id)
    end

    def self.user_json(row, users, position, metric: "volume")
      user = users[row.user_id]
      value = metric == "accuracy" ? row.accuracy_rate : row.questions_attempted
      {
        position: position,
        id: row.user_id,
        username: user&.username,
        name: user&.name,
        avatar_template: user&.avatar_template,
        questions_attempted: row.questions_attempted,
        questions_correct: row.questions_correct,
        accuracy_rate: row.accuracy_rate,
        value: value,
      }
    end

    def self.user_json_from_user(user, global_row)
      {
        id: user.id,
        username: user.username,
        name: user.name,
        avatar_template: user.avatar_template,
        questions_attempted: global_row&.questions_attempted.to_i,
        questions_correct: global_row&.questions_correct.to_i,
        accuracy_rate: global_row&.accuracy_rate,
      }
    end

    def self.empty_payload(metric, page, per_page)
      {
        metric: metric,
        period: "all",
        period_start: QuizLeaderboardStat.period_start_for("all"),
        page: page,
        per_page: per_page || 50,
        total: 0,
        users: [],
        personal: nil,
        refreshed_at: nil,
      }
    end

    def self.period_scope(scope, period:, period_start:)
      if ActiveRecord::Base.connection.column_exists?(:discourse_quiz_leaderboard_stats, :period_type) &&
           ActiveRecord::Base.connection.column_exists?(:discourse_quiz_leaderboard_stats, :period_start)
        scope.for_period(period, period_start)
      else
        scope
      end
    end
  end
end
