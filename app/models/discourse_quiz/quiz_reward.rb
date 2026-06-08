# frozen_string_literal: true

module DiscourseQuiz
  class QuizReward < ::ActiveRecord::Base
    self.table_name = "discourse_quiz_rewards"

    has_many :claims,
             class_name: "DiscourseQuiz::QuizRewardClaim",
             foreign_key: :reward_id,
             dependent: :destroy

    validates :name, presence: true
    validates :points_threshold, numericality: { only_integer: true, greater_than: 0 }
    validates :stock, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
    validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

    scope :active, -> { where(active: true) }
    scope :ordered, -> { order(position: :asc, id: :asc) }

    def self.table_ready?
      ActiveRecord::Base.connection.table_exists?(:discourse_quiz_rewards)
    end

    def unlimited_stock?
      stock.nil?
    end

    def in_stock?
      unlimited_stock? || remaining_stock.to_i.positive?
    end

    def remaining_stock
      return nil if unlimited_stock?

      [stock.to_i - claims.active_claims.count, 0].max
    end
  end
end
