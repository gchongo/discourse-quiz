# frozen_string_literal: true

module DiscourseQuiz
  class QuizPointsService
    def self.award_points(user, question, attempt)
      return unless user && SiteSetting.quiz_plugin_enabled
      return unless attempt.is_correct

      # 1. Check if gamification is enabled and available
      return unless gamification_active?

      # Wrap in transaction to prevent race conditions during point awarding
      QuizUserAttempt.transaction do
        # 2. Idempotency: Has this question already awarded points for this user?
        # Re-check inside transaction for strict protection
        return if already_awarded?(user, question)

        # 3. Check daily limit
        return if daily_limit_reached?(user)

        # 4. Award points via Gamification plugin
        points = SiteSetting.quiz_points_per_question
        if award_via_gamification(user, points, question)
          attempt.update!(score_awarded: true)
        end
      end
    end

    def self.gamification_active?
      # We check for the plugin's existence and if it's enabled via site setting
      SiteSetting.try(:discourse_gamification_enabled) && defined?(::DiscourseGamification)
    end

    def self.already_awarded?(user, question)
      QuizUserAttempt.where(user_id: user.id, question_id: question.id, is_correct: true, score_awarded: true).exists?
    end

    def self.daily_limit_reached?(user)
      points_today = QuizUserAttempt.awarded_today(user.id).count * SiteSetting.quiz_points_per_question
      points_today >= SiteSetting.quiz_daily_max_points
    end

    def self.award_via_gamification(user, points, question)
      # TODO: Use official Gamification API if available. 
      # Based on current discourse-gamification code, we insert into gamification_score_events
      if defined?(::DiscourseGamification::GamificationScoreEvent)
        ::DiscourseGamification::GamificationScoreEvent.create!(
          user_id: user.id,
          points: points,
          date: Date.today,
          description: "Quiz: #{question.category_name}"
        )
        true
      else
        false
      end
    rescue => e
      # Ensure plugin doesn't crash if Gamification has issues
      Rails.logger.error("Failed to award quiz points for user #{user.id}: #{e.message}")
      false
    end
  end
end
