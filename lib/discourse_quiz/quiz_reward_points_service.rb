# frozen_string_literal: true

module DiscourseQuiz
  class QuizRewardPointsService
    def self.cumulative_points_for(user)
      return 0 unless user

      if use_gamification_score?
        gamification_score_for(user)
      else
        quiz_points_total_for(user.id)
      end
    end

    def self.use_gamification_score?
      SiteSetting.quiz_rewards_use_gamification_score &&
        defined?(::DiscourseGamification) &&
        SiteSetting.try(:discourse_gamification_enabled)
    end

    def self.gamification_score_for(user)
      user.gamification_score.to_i
    rescue StandardError
      0
    end

    def self.quiz_points_total_for(user_id)
      return 0 unless QuizUserAttempt.table_ready?

      QuizUserAttempt
        .where(user_id: user_id, is_correct: true, score_awarded: true)
        .sum { |attempt| QuizPointsTierService.attempt_points_value(attempt) }
    end
  end
end
