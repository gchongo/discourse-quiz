# frozen_string_literal: true

RSpec.describe DiscourseQuiz::QuizRewardsController do
  fab!(:user)
  fab!(:reward) do
    DiscourseQuiz::QuizReward.create!(
      name: "Bookmark",
      category: "book",
      points_threshold: 5,
      active: true,
    )
  end

  before do
    SiteSetting.quiz_plugin_enabled = true
    SiteSetting.quiz_rewards_enabled = true
    SiteSetting.quiz_rewards_use_gamification_score = false
  end

  def award_points!
    question = DiscourseQuiz::QuizQuestion.create!(
      category_name: "测试",
      question_text: "Reward question",
      question_type: "single_choice",
      options: %w[A B],
      correct_index: 0,
      active: true,
    )

    DiscourseQuiz::QuizUserAttempt.create!(
      user_id: user.id,
      question_id: question.id,
      is_correct: true,
      score_awarded: true,
      points_awarded: 10,
    )
  end

  describe "GET /quiz/rewards.json" do
    it "returns active rewards" do
      get "/quiz/rewards.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["rewards"].length).to eq(1)
      expect(response.parsed_body["rewards"][0]["name"]).to eq("Bookmark")
    end

    it "is hidden when rewards are disabled" do
      SiteSetting.quiz_rewards_enabled = false

      get "/quiz/rewards.json"
      expect(response.status).to eq(404)
    end
  end

  describe "POST /quiz/rewards/:id/claim.json" do
    it "requires login" do
      post "/quiz/rewards/#{reward.id}/claim.json"
      expect(response.status).to eq(403)
    end

    it "creates a claim for eligible users" do
      award_points!
      sign_in(user)

      post "/quiz/rewards/#{reward.id}/claim.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["claim"]["status"]).to eq("pending")
      expect(response.parsed_body["cumulative_points"]).to eq(10)
      expect(DiscourseQuiz::QuizRewardClaim.where(user_id: user.id, reward_id: reward.id).count).to eq(1)
    end
  end
end
