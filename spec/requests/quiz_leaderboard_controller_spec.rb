# frozen_string_literal: true

RSpec.describe DiscourseQuiz::QuizLeaderboardController do
  fab!(:user) { Fabricate(:user) }

  let!(:question) do
    DiscourseQuiz::QuizQuestion.create!(
      category_name: "测试",
      question_text: "Leaderboard Q",
      options: %w[A B],
      correct_index: 0,
      active: true,
    )
  end

  before do
    SiteSetting.quiz_plugin_enabled = true
    SiteSetting.quiz_leaderboard_enabled = true

    DiscourseQuiz::QuizUserAttempt.create!(
      user_id: user.id,
      question_id: question.id,
      is_correct: true,
    )
    DiscourseQuiz::QuizLeaderboardRefreshService.refresh_all!
  end

  describe "GET /quiz/leaderboard.json" do
    it "returns rankings when enabled" do
      sign_in(user)

      get "/quiz/leaderboard.json", params: { metric: "volume" }

      expect(response.status).to eq(200)
      expect(response.parsed_body["users"].length).to eq(1)
      expect(response.parsed_body["users"][0]["username"]).to eq(user.username)
      expect(response.parsed_body["personal"]["position"]).to eq(1)
    end

    it "is hidden when leaderboard is disabled" do
      SiteSetting.quiz_leaderboard_enabled = false

      get "/quiz/leaderboard.json"
      expect(response.status).to eq(404)
    end
  end

  describe "GET /quiz/leaderboard/user_categories.json" do
    it "returns category stats for a username" do
      get "/quiz/leaderboard/user_categories.json", params: { username: user.username }

      expect(response.status).to eq(200)
      expect(response.parsed_body["user"]["questions_attempted"]).to eq(1)
      expect(response.parsed_body["categories"].length).to eq(1)
      expect(response.parsed_body["categories"][0]["category_name"]).to eq("测试")
    end

    it "returns 404 for unknown users" do
      get "/quiz/leaderboard/user_categories.json", params: { username: "nobody_here_12345" }
      expect(response.status).to eq(404)
    end
  end
end
