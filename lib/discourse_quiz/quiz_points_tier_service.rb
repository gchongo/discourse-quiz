# frozen_string_literal: true

module DiscourseQuiz
  class QuizPointsTierService
    def self.tiers_enabled?
      tier1_upto_count.positive?
    end

    def self.tier1_upto_count
      SiteSetting.quiz_tier1_upto_count.to_i
    end

    def self.tier2_upto_count
      SiteSetting.quiz_tier2_upto_count.to_i
    end

    def self.tier1_points
      SiteSetting.quiz_tier1_points.to_i
    end

    def self.tier2_points
      SiteSetting.quiz_tier2_points.to_i
    end

    def self.tier3_points
      SiteSetting.quiz_tier3_points.to_i
    end

    def self.flat_points_per_question
      SiteSetting.quiz_points_per_question.to_i
    end

    def self.daily_max_points
      SiteSetting.quiz_daily_max_points.to_i
    end

    def self.points_for_award_index(award_index)
      unless tiers_enabled?
        return flat_points_per_question
      end

      index = award_index.to_i
      first_tier_end = tier1_upto_count
      second_tier_end = tier2_upto_count

      if index < first_tier_end
        tier1_points
      elsif second_tier_end > first_tier_end && index < second_tier_end
        tier2_points
      else
        tier3_points
      end
    end

    def self.points_earned_today(user_id)
      return 0 unless QuizUserAttempt.table_ready?

      QuizUserAttempt.awarded_today(user_id).sum { |attempt| attempt_points_value(attempt) }
    end

    def self.attempt_points_value(attempt)
      if QuizUserAttempt.points_awarded_column? && attempt.points_awarded.to_i.positive?
        return attempt.points_awarded.to_i
      end

      attempt.score_awarded? ? flat_points_per_question : 0
    end

    def self.awardable_points_for(user_id)
      daily_max = daily_max_points
      return 0 if daily_max <= 0

      remaining = [daily_max - points_earned_today(user_id), 0].max
      return 0 if remaining <= 0

      awarded_count = awarded_today_count(user_id)
      tier_points = points_for_award_index(awarded_count)
      [tier_points, remaining].min
    end

    def self.awarded_today_count(user_id)
      return 0 unless QuizUserAttempt.table_ready?

      QuizUserAttempt.awarded_today(user_id).count
    end
  end
end
