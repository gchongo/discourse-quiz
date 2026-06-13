# frozen_string_literal: true

module DiscourseQuiz
  class QuizLeaderboardController < ::ApplicationController
    requires_plugin DiscourseQuiz::PLUGIN_NAME

    before_action :ensure_leaderboard_enabled
    before_action :ensure_tables_ready

    def index
      discourse_expires_in 1.minute

      render_json_dump(
        QuizLeaderboardRankingService.ranking(
          metric: params[:metric],
          period: params[:period],
          page: params[:page],
          per_page: params[:per_page],
          for_user_id: current_user&.id,
        ),
      )
    end

    def user_categories
      discourse_expires_in 1.minute

      user = resolve_user
      raise Discourse::NotFound unless user

      payload = QuizLeaderboardRankingService.user_categories(user, period: params[:period])
      raise Discourse::NotFound unless payload

      render_json_dump(payload)
    end

    private

    def ensure_leaderboard_enabled
      raise Discourse::NotFound unless SiteSetting.quiz_leaderboard_enabled
    end

    def ensure_tables_ready
      unless QuizUserAttempt.table_ready? && QuizLeaderboardStat.table_ready?
        return(
          render_json_dump(
            { error_code: :leaderboard_unavailable },
            status: 503,
          )
        )
      end
    end

    def resolve_user
      if params[:username].present?
        User.find_by_username(params[:username])
      elsif params[:user_id].present?
        User.find_by(id: params[:user_id].to_i)
      elsif current_user
        current_user
      end
    end
  end
end
