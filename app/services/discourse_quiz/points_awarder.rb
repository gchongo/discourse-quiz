# frozen_string_literal: true

module DiscourseQuiz
  class PointsAwarder
    include Service::Base

    params do
      attribute :user
      attribute :question
      attribute :attempt
    end

    only_if(:should_award_points)

    step :validate_not_already_awarded
    step :validate_daily_limit_not_reached

    transaction do
      step :create_gamification_event
      step :mark_attempt_awarded
    end

    step :enqueue_score_refresh

    private

    def should_award_points(params:)
      params.user.present? && SiteSetting.quiz_plugin_enabled && params.attempt.is_correct &&
        gamification_active?
    end

    def validate_not_already_awarded(params:)
      return if !already_awarded?(params.user, params.question)

      fail!(:already_awarded)
    end

    def validate_daily_limit_not_reached(params:)
      return if !daily_limit_reached?(params.user)

      fail!(:daily_limit_reached)
    end

    def create_gamification_event(params:)
      points = SiteSetting.quiz_points_per_question
      ::DiscourseGamification::GamificationScoreEvent.create!(
        user_id: params.user.id,
        points: points,
        date: Date.today,
        description: "Quiz: #{params.question.category_name}",
      )
    rescue StandardError => e
      Rails.logger.error(
        "[discourse-quiz] Failed to award points for user #{params.user.id}: #{e.message}",
      )
      fail!(:gamification_event_failed)
    end

    def mark_attempt_awarded(params:)
      params.attempt.update!(score_awarded: true)
    end

    def enqueue_score_refresh
      return unless defined?(Jobs::UpdateScoresForToday)

      Jobs.enqueue(Jobs::UpdateScoresForToday)
    end

    def gamification_active?
      defined?(::DiscourseGamification) && SiteSetting.try(:discourse_gamification_enabled)
    end

    def already_awarded?(user, question)
      QuizUserAttempt.where(
        user_id: user.id,
        question_id: question.id,
        is_correct: true,
        score_awarded: true,
      ).exists?
    end

    def daily_limit_reached?(user)
      points_today =
        QuizUserAttempt.awarded_today(user.id).count * SiteSetting.quiz_points_per_question
      points_today >= SiteSetting.quiz_daily_max_points
    end
  end
end
