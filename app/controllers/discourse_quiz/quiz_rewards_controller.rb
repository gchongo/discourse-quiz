# frozen_string_literal: true

module DiscourseQuiz
  class QuizRewardsController < ::ApplicationController
    requires_plugin DiscourseQuiz::PLUGIN_NAME

    before_action :ensure_rewards_enabled
    before_action :ensure_logged_in, only: %i[claim claims]

    def index
      unless rewards_tables_ready?
        return render_json_dump(rewards_payload(rewards: []))
      end

      rewards = QuizReward.active.ordered
      render_json_dump(rewards_payload(rewards: rewards.map { |reward| reward_json(reward) }))
    end

    def claims
      unless rewards_tables_ready?
        return render_json_dump(claims: [], cumulative_points: 0)
      end

      claims =
        QuizRewardClaim
          .where(user_id: current_user.id)
          .includes(:reward)
          .order(created_at: :desc)

      render_json_dump(
        claims: claims.map { |claim| claim_json(claim) },
        cumulative_points: QuizRewardPointsService.cumulative_points_for(current_user),
      )
    end

    def claim
      unless rewards_tables_ready?
        return render_json_dump({ error_code: :rewards_unavailable }, status: 503)
      end

      reward = QuizReward.active.find_by(id: params[:id])
      raise Discourse::NotFound unless reward

      claim = QuizRewardClaimService.claim!(current_user, reward)

      render_json_dump(
        claim: claim_json(claim),
        cumulative_points: QuizRewardPointsService.cumulative_points_for(current_user),
      )
    rescue QuizRewardClaimService::Error => e
      render_json_dump(
        { error_code: e.error_code, error: claim_error_message(e.error_code) },
        status: claim_error_status(e.error_code),
      )
    end

    private

    def ensure_rewards_enabled
      raise Discourse::NotFound unless SiteSetting.quiz_rewards_enabled
    end

    def rewards_tables_ready?
      QuizReward.table_ready? && QuizRewardClaim.table_ready?
    end

    def rewards_payload(rewards:)
      {
        rewards: rewards,
        cumulative_points: current_user ? QuizRewardPointsService.cumulative_points_for(current_user) : 0,
        points_source: QuizRewardPointsService.use_gamification_score? ? "gamification" : "quiz",
        logged_in: current_user.present?,
      }
    end

    def reward_json(reward)
      claim = current_user_claim(reward.id)
      active_claim = claim unless claim&.status == "cancelled"
      points = current_user ? QuizRewardPointsService.cumulative_points_for(current_user) : 0

      {
        id: reward.id,
        name: reward.name,
        description: reward.description,
        category: reward.category,
        image_url: reward.image_url,
        points_threshold: reward.points_threshold,
        remaining_stock: reward.remaining_stock,
        in_stock: reward.in_stock?,
        claim_status: active_claim&.status,
        claimable:
          current_user.present? && active_claim.nil? && reward.in_stock? &&
            points >= reward.points_threshold,
      }
    end

    def current_user_claim(reward_id)
      return nil unless current_user && rewards_tables_ready?

      QuizRewardClaim.find_by(user_id: current_user.id, reward_id: reward_id)
    end

    def claim_json(claim)
      {
        id: claim.id,
        reward_id: claim.reward_id,
        reward_name: claim.reward&.name,
        reward_description: claim.reward&.description,
        status: claim.status,
        created_at: claim.created_at,
      }
    end

    def claim_error_message(error_code)
      I18n.t("discourse_quiz.rewards.errors.#{error_code}", default: error_code.to_s)
    end

    def claim_error_status(error_code)
      case error_code
      when :login_required
        403
      when :insufficient_points, :already_claimed, :reward_out_of_stock, :reward_inactive
        422
      else
        503
      end
    end
  end
end
