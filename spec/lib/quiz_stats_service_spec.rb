# frozen_string_literal: true

require "rails_helper"

describe DiscourseQuiz::QuizStatsService do
  let(:user) { Fabricate(:user) }

  let!(:history_q) do
    DiscourseQuiz::QuizQuestion.create!(
      category_name: "历史",
      question_text: "Q1",
      options: %w[A B],
      correct_index: 0,
    )
  end

  let!(:geo_q) do
    DiscourseQuiz::QuizQuestion.create!(
      category_name: "地理",
      question_text: "Q2",
      options: %w[A B],
      correct_index: 1,
    )
  end

  it "returns nil for guests" do
    expect(described_class.new(nil).summary).to be_nil
  end

  it "summarizes today counts and pending practice pools" do
    DiscourseQuiz::QuizUserAttempt.create!(
      user_id: user.id,
      question_id: history_q.id,
      answer_index: 1,
      is_correct: false,
      created_at: Time.zone.now,
    )

    DiscourseQuiz::QuizUserAttempt.create!(
      user_id: user.id,
      question_id: geo_q.id,
      answer_index: 1,
      is_correct: true,
      created_at: Time.zone.now,
    )

    stats = described_class.new(user).summary

    expect(stats[:today_correct]).to eq(1)
    expect(stats[:today_incorrect]).to eq(1)
    expect(stats[:wrong_pending]).to eq(1)
    expect(stats[:unseen_pending]).to eq(0)
    expect(stats[:questions_in_scope]).to eq(2)
  end
end
