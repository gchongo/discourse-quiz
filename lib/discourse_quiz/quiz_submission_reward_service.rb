# frozen_string_literal: true

module DiscourseQuiz
  class QuizSubmissionRewardService
    def self.reward_for_approved_submission(submission)
      return no_reward(:disabled) unless SiteSetting.quiz_submission_reward_enabled
      return no_reward(:invalid_submission) unless submission&.status == "approved"
      return no_reward(:table_not_ready) unless reward_log_table_ready?
      return no_reward(:gamification_disabled) unless QuizPointsService.gamification_active?

      user = User.find_by(id: submission.submitter_id)
      return no_reward(:user_not_found) unless user

      points_per_submission = SiteSetting.quiz_submission_reward_points.to_i
      daily_cap = SiteSetting.quiz_submission_reward_daily_cap.to_i
      return no_reward(:invalid_settings) if points_per_submission <= 0 || daily_cap <= 0

      awarded_points = 0
      reason = "approved"
      reward_failed = false

      QuizSubmissionRewardLog.transaction do
        lock_reward_scope!(user.id)

        existing = QuizSubmissionRewardLog.find_by(submission_id: submission.id)
        if existing
          awarded_points = existing.points_awarded
          reason = existing.reason
          next
        end

        earned_today = points_earned_today(user.id)
        remaining_today = [daily_cap - earned_today, 0].max
        awarded_points = [points_per_submission, remaining_today].min
        reason = awarded_points > 0 ? "approved" : "daily_cap_reached"

        if awarded_points > 0
          awarded = QuizPointsService.award_via_gamification(user, awarded_points, reward_description(submission))
          unless awarded
            awarded_points = 0
            reason = "award_failed"
            reward_failed = true
            raise ActiveRecord::Rollback
          end
        end

        QuizSubmissionRewardLog.create!(
          submission_id: submission.id,
          user_id: user.id,
          points_awarded: awarded_points,
          awarded_on: Time.zone.today,
          reason: reason,
        )

        QuizPointsService.enqueue_score_refresh if awarded_points > 0
      end

      if reward_failed
        return no_reward(reason)
      end

      persisted = QuizSubmissionRewardLog.find_by(submission_id: submission.id)
      return { awarded_points: persisted.points_awarded, reason: persisted.reason } if persisted

      { awarded_points: awarded_points, reason: reason }
    rescue ActiveRecord::RecordNotUnique
      existing = QuizSubmissionRewardLog.find_by(submission_id: submission.id)
      return { awarded_points: existing&.points_awarded.to_i, reason: existing&.reason || "record_not_unique" }
    rescue StandardError => e
      Rails.logger.error(
        "[discourse-quiz] submission reward failed for submission #{submission&.id}: #{e.class}: #{e.message}",
      )
      no_reward(:error)
    end

    def self.no_reward(reason)
      { awarded_points: 0, reason: reason.to_s }
    end

    def self.points_earned_today(user_id)
      QuizSubmissionRewardLog
        .where(user_id: user_id, awarded_on: Time.zone.today)
        .sum(:points_awarded)
    end

    def self.reward_log_table_ready?
      ActiveRecord::Base.connection.table_exists?(:discourse_quiz_submission_reward_logs)
    end

    def self.lock_reward_scope!(user_id)
      User.where(id: user_id).lock(true).pick(:id)
    end

    def self.reward_description(submission)
      category = submission.category_name.presence || "quiz"
      "Quiz submission approved: #{category}"
    end
  end
end
