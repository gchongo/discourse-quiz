# frozen_string_literal: true

module DiscourseQuiz
  class QuizPointsService
    def self.award_points(user, question, attempt)
      return unless user && SiteSetting.quiz_plugin_enabled
      return unless attempt.is_correct
      return unless gamification_active?
      return unless attempts_table_ready?

      QuizUserAttempt.transaction do
        lock_award_scope!(user.id)
        return if already_awarded?(user, question)
        return if daily_limit_reached?(user)

        points = QuizPointsTierService.awardable_points_for(user.id)
        return if points <= 0

        if award_via_gamification(user, points, question)
          attrs = { score_awarded: true }
          if QuizUserAttempt.points_awarded_column?
            attrs[:points_awarded] = points
          end
          attempt.update!(attrs)
          enqueue_score_refresh
        end
      end
    rescue ActiveRecord::RecordNotUnique
      # Concurrent submissions for the same question can race; unique DB index is source of truth.
      nil
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
      QuizPointsTierService.points_earned_today(user.id) >= QuizPointsTierService.daily_max_points
    end

    def self.award_via_gamification(user, points, question_or_description)
      return false unless defined?(::DiscourseGamification::GamificationScoreEvent)

      description = score_description(question_or_description)
      ::DiscourseGamification::GamificationScoreEvent.create!(
        user_id: user.id,
        points: points,
        date: Time.zone.today,
        description: description,
      )
      true
    rescue StandardError => e
      Rails.logger.error("[discourse-quiz] Failed to award points for user #{user.id}: #{e.message}")
      false
    end

    def self.enqueue_score_refresh
      return unless defined?(Jobs::UpdateScoresForToday)

      Jobs.enqueue(Jobs::UpdateScoresForToday)
    end

    def self.attempts_table_ready?
      ActiveRecord::Base.connection.table_exists?(:discourse_quiz_user_attempts)
    end

    def self.lock_award_scope!(user_id)
      User.where(id: user_id).lock(true).pick(:id)
    end

    def self.score_description(question_or_description)
      return question_or_description if question_or_description.is_a?(String)

      category_name = question_or_description.respond_to?(:category_name) ? question_or_description.category_name : nil
      "Quiz: #{category_name.presence || 'quiz'}"
    end
  end
end
