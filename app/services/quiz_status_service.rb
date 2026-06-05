# frozen_string_literal: true

module DiscourseGamifiedQuiz
  class QuizStatusService
    def initialize(user, guest_attempts_count = 0)
      @user = user
      @guest_attempts_count = guest_attempts_count.to_i
    end

    def get_status
      if @user
        logged_in_status
      else
        guest_status
      end
    end

    def can_play?
      status = get_status
      status[:mode] != :paywall
    end

    private

    def logged_in_status
      points_today = QuizUserAttempt.awarded_today(@user.id).count * SiteSetting.quiz_points_per_question

      daily_max = SiteSetting.quiz_daily_max_points
      mode = points_today >= daily_max ? :learning_only : :normal

      {
        is_guest: false,
        points_today: points_today,
        daily_max_reached: points_today >= daily_max,
        mode: mode
      }
    end

    def guest_status
      unless SiteSetting.quiz_enable_guest_demo
        return { is_guest: true, mode: :paywall, attempts_left: 0 }
      end

      limit = SiteSetting.quiz_guest_attempt_limit
      mode = @guest_attempts_count >= limit ? :paywall : :normal

      {
        is_guest: true,
        attempts_left: [0, limit - @guest_attempts_count].max,
        mode: mode,
        paywall_message: mode == :paywall ? SiteSetting.quiz_guest_paywall_message : nil
      }
    end
  end
end
