# frozen_string_literal: true

RSpec.describe DiscourseQuiz::QuizLeaderboardRefreshService do
  fab!(:user) { Fabricate(:user) }
  fab!(:other_user) { Fabricate(:user) }

  let!(:history_q) do
    DiscourseQuiz::QuizQuestion.create!(
      category_name: "历史",
      question_text: "History Q",
      options: %w[A B],
      correct_index: 0,
      active: true,
    )
  end

  let!(:geo_q) do
    DiscourseQuiz::QuizQuestion.create!(
      category_name: "地理",
      question_text: "Geo Q",
      options: %w[A B],
      correct_index: 0,
      active: true,
    )
  end

  def create_attempt!(question:, user:, correct:)
    DiscourseQuiz::QuizUserAttempt.create!(
      user_id: user.id,
      question_id: question.id,
      is_correct: correct,
    )
  end

  describe ".refresh_all!" do
    it "counts distinct questions and correct questions per user" do
      create_attempt!(question: history_q, user: user, correct: true)
      create_attempt!(question: history_q, user: user, correct: true)
      create_attempt!(question: geo_q, user: user, correct: false)

      described_class.refresh_all!

      global = DiscourseQuiz::QuizLeaderboardStat.global_rows.find_by(user_id: user.id)
      expect(global.questions_attempted).to eq(2)
      expect(global.questions_correct).to eq(1)
      expect(global.accuracy_rate).to eq(50.0)
    end

    it "stores per-category rows" do
      create_attempt!(question: history_q, user: user, correct: true)
      create_attempt!(question: geo_q, user: user, correct: true)

      described_class.refresh_all!

      history_row =
        DiscourseQuiz::QuizLeaderboardStat.category_rows.find_by(
          user_id: user.id,
          category_name: "历史",
        )
      geo_row =
        DiscourseQuiz::QuizLeaderboardStat.category_rows.find_by(
          user_id: user.id,
          category_name: "地理",
        )

      expect(history_row.questions_attempted).to eq(1)
      expect(history_row.questions_correct).to eq(1)
      expect(history_row.accuracy_rate).to eq(100.0)
      expect(geo_row.questions_attempted).to eq(1)
      expect(geo_row.questions_correct).to eq(1)
    end
  end

  describe ".refresh_user!" do
    it "refreshes only the given user" do
      create_attempt!(question: history_q, user: user, correct: true)
      create_attempt!(question: geo_q, user: other_user, correct: true)

      described_class.refresh_user!(user.id)

      expect(DiscourseQuiz::QuizLeaderboardStat.global_rows.count).to eq(1)
      expect(DiscourseQuiz::QuizLeaderboardStat.global_rows.find_by(user_id: user.id)).to be_present
      expect(DiscourseQuiz::QuizLeaderboardStat.global_rows.find_by(user_id: other_user.id)).to be_nil
    end
  end
end
