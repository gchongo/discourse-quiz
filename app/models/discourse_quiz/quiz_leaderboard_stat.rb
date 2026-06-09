# frozen_string_literal: true

module DiscourseQuiz
  class QuizLeaderboardStat < ::ActiveRecord::Base
    self.table_name = "discourse_quiz_leaderboard_stats"

    GLOBAL_CATEGORY = ""

    belongs_to :user

    scope :global_rows, -> { where(category_name: GLOBAL_CATEGORY) }
    scope :category_rows, -> { where.not(category_name: GLOBAL_CATEGORY) }

    def self.table_ready?
      ActiveRecord::Base.connection.table_exists?(:discourse_quiz_leaderboard_stats)
    end
  end
end
