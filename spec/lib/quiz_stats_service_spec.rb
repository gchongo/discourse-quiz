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

  it "summarizes lifetime correct and never-correct questions" do
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

    DiscourseQuiz::QuizUserAttempt.create!(
      user_id: user.id,
      question_id: geo_q.id,
      answer_index: 1,
      is_correct: true,
      created_at: 1.hour.ago,
    )

    stats = described_class.new(user).summary

    expect(stats[:lifetime_correct]).to eq(2)
    expect(stats[:wrong_questions]).to eq(1)
    expect(stats[:unseen_pending]).to eq(0)
    expect(stats[:questions_in_scope]).to eq(2)
  end

  it "removes a question from wrong_questions after it is answered correctly" do
    DiscourseQuiz::QuizUserAttempt.create!(
      user_id: user.id,
      question_id: history_q.id,
      answer_index: 1,
      is_correct: false,
      created_at: 2.hours.ago,
    )

    DiscourseQuiz::QuizUserAttempt.create!(
      user_id: user.id,
      question_id: history_q.id,
      answer_index: 0,
      is_correct: true,
      created_at: Time.zone.now,
    )

    stats = described_class.new(user).summary

    expect(stats[:lifetime_correct]).to eq(1)
    expect(stats[:wrong_questions]).to eq(0)
  end
end
