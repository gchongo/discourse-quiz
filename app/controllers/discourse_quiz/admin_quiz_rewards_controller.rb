# frozen_string_literal: true

module DiscourseQuiz
  class AdminQuizRewardsController < ::Admin::AdminController
    requires_plugin DiscourseQuiz::PLUGIN_NAME

    def index
      unless rewards_tables_ready?
        return(
          render_json_dump(
            rewards: [],
            claims: [],
            error: I18n.t("discourse_quiz.errors.database_unavailable"),
          )
        )
      end

      rewards = QuizReward.ordered
      claims =
        QuizRewardClaim
          .includes(:reward, :user)
          .order(created_at: :desc)
          .limit(claims_limit)

      render_json_dump(
        rewards: rewards.map { |reward| admin_reward_json(reward) },
        claims: claims.map { |claim| admin_claim_json(claim) },
      )
    rescue ActiveRecord::StatementInvalid => e
      Rails.logger.error("[discourse-quiz] admin rewards#index failed: #{e.message}")
      render_json_dump(
        { rewards: [], claims: [], error: I18n.t("discourse_quiz.errors.database_unavailable") },
        status: 500,
      )
    end

    def create
      reward = QuizReward.new(reward_attributes(params.require(:reward)))

      if reward.save
        render_json_dump(reward: admin_reward_json(reward))
      else
        render_json_dump({ errors: reward.errors.full_messages }, status: 422)
      end
    end

    def update
      reward = QuizReward.find(params[:id])

      if reward.update(reward_attributes(params.require(:reward)))
        render_json_dump(reward: admin_reward_json(reward))
      else
        render_json_dump({ errors: reward.errors.full_messages }, status: 422)
      end
    end

    def destroy
      reward = QuizReward.find(params[:id])
      reward.destroy!
      render_json_dump(success: true)
    end

    def update_claim
      claim = QuizRewardClaim.find(params[:id])
      status = params.require(:status).to_s

      unless QuizRewardClaim::STATUSES.include?(status)
        return render_json_dump({ errors: [I18n.t("discourse_quiz.rewards.errors.invalid_status")] }, status: 422)
      end

      QuizRewardClaim.transaction do
        previous_status = claim.status
        claim.update!(status: status)
        restore_reward_stock!(claim.reward) if should_restore_stock?(previous_status, status)
      end

      render_json_dump(claim: admin_claim_json(claim))
    end

    private

    def rewards_tables_ready?
      QuizReward.table_ready? && QuizRewardClaim.table_ready?
    end

    def claims_limit
      limit = params[:claims_limit].to_i
      limit = 50 if limit <= 0
      [limit, 200].min
    end

    def reward_attributes(raw)
      attrs = raw.permit(:name, :description, :category, :image_url, :points_threshold, :stock, :position, :active)

      if attrs.key?(:stock) && attrs[:stock].to_s.strip.blank?
        attrs[:stock] = nil
      end

      attrs
    end

    def admin_reward_json(reward)
      {
        id: reward.id,
        name: reward.name,
        description: reward.description,
        category: reward.category,
        image_url: reward.image_url,
        points_threshold: reward.points_threshold,
        stock: reward.stock,
        remaining_stock: reward.remaining_stock,
        position: reward.position,
        active: reward.active,
        claims_count: reward.claims.where.not(status: "cancelled").count,
      }
    end

    def should_restore_stock?(previous_status, new_status)
      new_status == "cancelled" && previous_status != "cancelled"
    end

    def restore_reward_stock!(reward)
      return unless reward
      return if reward.unlimited_stock?

      reward.update!(stock: reward.stock.to_i + 1)
    end

    def admin_claim_json(claim)
      {
        id: claim.id,
        user_id: claim.user_id,
        username: claim.user&.username,
        reward_id: claim.reward_id,
        reward_name: claim.reward&.name,
        status: claim.status,
        created_at: claim.created_at,
      }
    end
  end
end
