# frozen_string_literal: true

module Jobs
  class RefreshQuizLeaderboardUser < ::Jobs::Base
    def execute(args)
      return unless SiteSetting.quiz_plugin_enabled && SiteSetting.quiz_leaderboard_enabled

      user_id = args[:user_id]
      return if user_id.blank?

      DiscourseQuiz::QuizLeaderboardRefreshService.refresh_user!(user_id)
    end
  end
end
