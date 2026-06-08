# frozen_string_literal: true

module DiscourseQuiz
  class QuizRewardClaim < ::ActiveRecord::Base
    self.table_name = "discourse_quiz_reward_claims"

    STATUSES = %w[pending fulfilled cancelled].freeze

    belongs_to :user
    belongs_to :reward, class_name: "DiscourseQuiz::QuizReward"

    validates :status, inclusion: { in: STATUSES }
    validates :user_id, uniqueness: { scope: :reward_id }

    scope :active_claims, -> { where.not(status: "cancelled") }

    def self.table_ready?
      ActiveRecord::Base.connection.table_exists?(:discourse_quiz_reward_claims)
    end
  end
end
