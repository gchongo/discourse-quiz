# frozen_string_literal: true

module DiscourseQuiz
  class QuizRewardClaimService
    class Error < StandardError
      attr_reader :error_code

      def initialize(error_code)
        @error_code = error_code
        super(error_code.to_s)
      end
    end

    def self.claim!(user, reward)
      raise Error, :rewards_unavailable unless rewards_ready?
      raise Error, :login_required unless user
      raise Error, :reward_inactive unless reward.active?
      raise Error, :reward_out_of_stock unless reward.in_stock?

      points = QuizRewardPointsService.cumulative_points_for(user)
      raise Error, :insufficient_points if points < reward.points_threshold

      if QuizRewardClaim.exists?(user_id: user.id, reward_id: reward.id)
        existing = QuizRewardClaim.find_by(user_id: user.id, reward_id: reward.id)
        raise Error, :already_claimed unless existing.status == "cancelled"
      end

      QuizRewardClaim.transaction do
        reward.lock! unless reward.unlimited_stock?

        if !reward.unlimited_stock? && reward.remaining_stock.to_i <= 0
          raise Error, :reward_out_of_stock
        end

        claim =
          QuizRewardClaim.find_or_initialize_by(user_id: user.id, reward_id: reward.id)

        if claim.persisted? && claim.status != "cancelled"
          raise Error, :already_claimed
        end

        reclaiming = claim.persisted? && claim.status == "cancelled"
        claim.status = "pending"
        claim.save!

        if !reward.unlimited_stock? && !reclaiming
          reward.update!(stock: reward.stock.to_i - 1)
        end

        claim
      end
    end

    def self.rewards_ready?
      SiteSetting.quiz_rewards_enabled && QuizReward.table_ready? &&
        QuizRewardClaim.table_ready?
    end
  end
end
