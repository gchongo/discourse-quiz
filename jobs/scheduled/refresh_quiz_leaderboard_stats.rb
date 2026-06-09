# frozen_string_literal: true

module Jobs
  class RefreshQuizLeaderboardStats < ::Jobs::Scheduled
    every 1.hour

    def execute(args = nil)
      return unless SiteSetting.quiz_plugin_enabled && SiteSetting.quiz_leaderboard_enabled

      DiscourseQuiz::QuizLeaderboardRefreshService.refresh_all!
    end
  end
end
