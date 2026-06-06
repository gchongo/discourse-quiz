# frozen_string_literal: true

require "rails_helper"

describe DiscourseQuiz::QuizPointsService do
  let(:user) { Fabricate(:user) }
  let!(:question) do
    DiscourseQuiz::QuizQuestion.create!(
      category_name: "历史",
      question_text: "Q",
      options: %w[A B],
      correct_index: 0,
    )
  end

  let(:attempt) do
    DiscourseQuiz::QuizUserAttempt.create!(
      user_id: user.id,
      question_id: question.id,
      answer_index: 0,
      is_correct: true,
      created_at: Time.zone.now,
    )
  end

  before do
    SiteSetting.quiz_plugin_enabled = true
    SiteSetting.quiz_points_per_question = 10
    SiteSetting.quiz_daily_max_points = 100
  end

  it "does not award points when gamification is disabled" do
    described_class.award_points(user, question, attempt)
    expect(attempt.reload.score_awarded).to eq(false)
  end

  it "awards points once when gamification is enabled" do
    skip "discourse-gamification plugin not loaded" unless defined?(::DiscourseGamification)

    SiteSetting.discourse_gamification_enabled = true

    described_class.award_points(user, question, attempt)
    expect(attempt.reload.score_awarded).to eq(true)
    expect(DiscourseGamification::GamificationScoreEvent.where(user_id: user.id).count).to eq(1)

    described_class.award_points(user, question, attempt)
    expect(DiscourseGamification::GamificationScoreEvent.where(user_id: user.id).count).to eq(1)
  end
end
