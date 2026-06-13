# frozen_string_literal: true

module DiscourseQuiz
  class QuizLeaderboardStat < ::ActiveRecord::Base
    self.table_name = "discourse_quiz_leaderboard_stats"

    GLOBAL_CATEGORY = ""
    ALL_PERIOD_START = Date.new(1970, 1, 1)
    PERIODS = %w[all yearly quarterly monthly weekly daily].freeze

    belongs_to :user

    scope :global_rows, -> { where(category_name: GLOBAL_CATEGORY) }
    scope :category_rows, -> { where.not(category_name: GLOBAL_CATEGORY) }
    scope :for_period, ->(period, period_start) { where(period_type: period, period_start: period_start) }

    def self.table_ready?
      ActiveRecord::Base.connection.table_exists?(:discourse_quiz_leaderboard_stats)
    end

    def self.normalize_period(period)
      candidate = period.to_s
      PERIODS.include?(candidate) ? candidate : "all"
    end

    def self.period_start_for(period, now: Time.zone.now)
      case normalize_period(period)
      when "daily"
        now.beginning_of_day.to_date
      when "weekly"
        (now.beginning_of_day - 6.days).to_date
      when "monthly"
        (now.beginning_of_day - 29.days).to_date
      when "quarterly"
        (now.beginning_of_day - 89.days).to_date
      when "yearly"
        (now.beginning_of_day - 364.days).to_date
      else
        ALL_PERIOD_START
      end
    end
  end
end
