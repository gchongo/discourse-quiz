# frozen_string_literal: true

module DiscourseQuiz
  class QuizPointsService
    def self.award_points(user, question, attempt)
      return unless user && SiteSetting.quiz_plugin_enabled
      return unless attempt.is_correct
      return unless gamification_active?

      QuizUserAttempt.transaction do
        return if already_awarded?(user, question)
        return if daily_limit_reached?(user)

        points = SiteSetting.quiz_points_per_question
        if award_via_gamification(user, points, question)
          attempt.update!(score_awarded: true)
          enqueue_score_refresh
        end
      end
    end

    def self.gamification_active?
      defined?(::DiscourseGamification) && SiteSetting.try(:discourse_gamification_enabled)
    end

    def self.already_awarded?(user, question)
      QuizUserAttempt.where(
        user_id: user.id,
        question_id: question.id,
        is_correct: true,
        score_awarded: true,
      ).exists?
    end

    def self.daily_limit_reached?(user)
      points_today =
        QuizUserAttempt.awarded_today(user.id).count * SiteSetting.quiz_points_per_question
      points_today >= SiteSetting.quiz_daily_max_points
    end

    def self.award_via_gamification(user, points, question)
      return false unless defined?(::DiscourseGamification::GamificationScoreEvent)

      ::DiscourseGamification::GamificationScoreEvent.create!(
        user_id: user.id,
        points: points,
        date: Date.today,
        description: "Quiz: #{question.category_name}",
      )
      true
    rescue StandardError => e
      Rails.logger.error(
        "Failed to award quiz points for user #{user.id}: #{e.message}",
      )
      false
    end

    def self.enqueue_score_refresh
      return unless defined?(Jobs::UpdateScoresForToday)

      Jobs.enqueue(Jobs::UpdateScoresForToday)
    end
  end
end
