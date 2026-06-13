# frozen_string_literal: true

RSpec.describe DiscourseQuiz::QuizLeaderboardRankingService do
  fab!(:top_user) { Fabricate(:user) }
  fab!(:mid_user) { Fabricate(:user) }
  fab!(:low_user) { Fabricate(:user) }

  let!(:questions) do
    25.times.map do |i|
      DiscourseQuiz::QuizQuestion.create!(
        category_name: "测试",
        question_text: "Q#{i}",
        options: %w[A B],
        correct_index: 0,
        active: true,
      )
    end
  end

  before do
    SiteSetting.quiz_leaderboard_min_attempts = 20

    questions.first(25).each_with_index do |q, i|
      DiscourseQuiz::QuizUserAttempt.create!(
        user_id: top_user.id,
        question_id: q.id,
        is_correct: i < 20,
      )
    end

    questions.first(22).each_with_index do |q, i|
      DiscourseQuiz::QuizUserAttempt.create!(
        user_id: mid_user.id,
        question_id: q.id,
        is_correct: i < 18,
      )
    end

    questions.first(5).each do |q|
      DiscourseQuiz::QuizUserAttempt.create!(
        user_id: low_user.id,
        question_id: q.id,
        is_correct: true,
      )
    end

    DiscourseQuiz::QuizLeaderboardRefreshService.refresh_all!
  end

  describe ".ranking" do
    it "orders volume by distinct questions attempted" do
      result = described_class.ranking(metric: "volume", page: 1, per_page: 10)

      expect(result[:users].map { |u| u[:username] }).to eq(
        [top_user.username, mid_user.username, low_user.username],
      )
      expect(result[:users].first[:questions_attempted]).to eq(25)
    end

    it "orders accuracy for users meeting the minimum attempts" do
      result = described_class.ranking(metric: "accuracy", page: 1, per_page: 10)

      usernames = result[:users].map { |u| u[:username] }
      expect(usernames).to include(top_user.username, mid_user.username)
      expect(usernames).not_to include(low_user.username)
      expect(result[:users].first[:accuracy_rate]).to be >= result[:users].second[:accuracy_rate]
    end

    it "returns personal rank for the current user" do
      result =
        described_class.ranking(
          metric: "volume",
          page: 1,
          per_page: 10,
          for_user_id: mid_user.id,
        )

      expect(result[:personal][:position]).to eq(2)
      expect(result[:personal][:questions_attempted]).to eq(22)
    end

    it "marks personal entry ineligible for accuracy when below minimum" do
      result =
        described_class.ranking(
          metric: "accuracy",
          page: 1,
          per_page: 10,
          for_user_id: low_user.id,
        )

      expect(result[:personal][:ineligible]).to eq(true)
      expect(result[:personal][:position]).to be_nil
    end

    it "returns period metadata and supports period filter" do
      result = described_class.ranking(metric: "volume", period: "weekly", page: 1, per_page: 10)

      expect(result[:period]).to eq("weekly")
      expect(result[:period_start]).to eq(Time.zone.today.beginning_of_week)
    end
  end

  describe ".user_categories" do
    fab!(:user) { Fabricate(:user) }

    let!(:history_q) do
      DiscourseQuiz::QuizQuestion.create!(
        category_name: "历史",
        question_text: "History",
        options: %w[A B],
        correct_index: 0,
        active: true,
      )
    end

    let!(:geo_q) do
      DiscourseQuiz::QuizQuestion.create!(
        category_name: "地理",
        question_text: "Geo",
        options: %w[A B],
        correct_index: 0,
        active: true,
      )
    end

    before do
      DiscourseQuiz::QuizUserAttempt.create!(
        user_id: user.id,
        question_id: history_q.id,
        is_correct: true,
      )
      DiscourseQuiz::QuizUserAttempt.create!(
        user_id: user.id,
        question_id: geo_q.id,
        is_correct: false,
      )
      DiscourseQuiz::QuizLeaderboardRefreshService.refresh_user!(user.id)
    end

    it "returns global and per-category stats" do
      payload = described_class.user_categories(user)

      expect(payload[:user][:questions_attempted]).to eq(2)
      expect(payload[:user][:questions_correct]).to eq(1)
      expect(payload[:categories].map { |c| c[:category_name] }).to contain_exactly("历史", "地理")
    end

    it "supports period filter on category stats" do
      payload = described_class.user_categories(user, period: "daily")

      expect(payload[:period]).to eq("daily")
      expect(payload[:period_start]).to eq(Time.zone.today)
    end
  end
end
