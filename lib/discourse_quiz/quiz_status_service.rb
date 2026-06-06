# frozen_string_literal: true

module DiscourseQuiz
  class QuizStatusService
    def initialize(user, guest_attempts_count = 0)
      @user = user
      @guest_attempts_count = guest_attempts_count.to_i
    end

    def get_status
      @user ? logged_in_status : guest_status
    end

    def can_play?
      get_status[:mode] != "paywall"
    end

    private

    def logged_in_status
      points_today = points_today_for(@user.id)
      daily_max = SiteSetting.quiz_daily_max_points
      daily_max_reached = points_today >= daily_max

      {
        is_guest: false,
        points_today: points_today,
        daily_max: daily_max,
        daily_max_reached: daily_max_reached,
        mode: daily_max_reached ? "learning_only" : "normal",
        stats: quiz_stats,
      }
    end

    def quiz_stats
      QuizStatsService.new(@user).summary(
        category_names: category_allowlist,
      )
    end

    def category_allowlist
      setting = SiteSetting.quiz_categories.to_s.strip
      return [] if setting.blank?

      setting.split(",").map(&:strip).reject(&:blank?)
    end

    def guest_status
      unless SiteSetting.quiz_enable_guest_demo
        return paywall_guest_status(attempts_left: 0)
      end

      limit = SiteSetting.quiz_guest_attempt_limit
      attempts_left = [0, limit - @guest_attempts_count].max
      paywall = @guest_attempts_count >= limit

      if paywall
        paywall_guest_status(attempts_left: 0)
      else
        {
          is_guest: true,
          attempts_left: attempts_left,
          attempt_limit: limit,
          mode: "normal",
          paywall_message: nil,
        }
      end
    end

    def paywall_guest_status(attempts_left:)
      {
        is_guest: true,
        attempts_left: attempts_left,
        attempt_limit: SiteSetting.quiz_guest_attempt_limit,
        mode: "paywall",
        paywall_message: SiteSetting.quiz_guest_paywall_message.presence,
      }
    end

    def points_today_for(user_id)
      return 0 unless attempts_table_ready?

      QuizUserAttempt.awarded_today(user_id).count * SiteSetting.quiz_points_per_question
    end

    def attempts_table_ready?
      ActiveRecord::Base.connection.table_exists?(:discourse_quiz_user_attempts)
    end
  end
end
