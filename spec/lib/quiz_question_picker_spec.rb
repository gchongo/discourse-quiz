# frozen_string_literal: true

require "rails_helper"

describe DiscourseQuiz::QuizQuestionPicker do
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

  describe "normal mode" do
    it "returns a random active question" do
      picker =
        described_class.new(
          user: user,
          category_names: ["历史"],
          practice_mode: "normal",
        )

      expect(picker.pick).to eq(history_q)
    end
  end

  describe "wrong_only mode" do
    it "returns only questions whose latest attempt was wrong" do
      DiscourseQuiz::QuizUserAttempt.create!(
        user_id: user.id,
        question_id: history_q.id,
        answer_index: 1,
        is_correct: false,
        created_at: 2.hours.ago,
      )

      DiscourseQuiz::QuizUserAttempt.create!(
        user_id: user.id,
        question_id: geo_q.id,
        answer_index: 1,
        is_correct: true,
        created_at: 1.hour.ago,
      )

      picker = described_class.new(user: user, practice_mode: "wrong_only")
      expect(picker.pick).to eq(history_q)
    end

    it "ignores questions corrected after a wrong attempt" do
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
        created_at: 1.hour.ago,
      )

      picker = described_class.new(user: user, practice_mode: "wrong_only")
      expect(picker.pick).to be_nil
      expect(picker.empty_reason).to eq(:no_wrong_questions)
    end
  end

  describe "unseen mode" do
    it "returns only questions the user has never attempted" do
      DiscourseQuiz::QuizUserAttempt.create!(
        user_id: user.id,
        question_id: history_q.id,
        answer_index: 0,
        is_correct: true,
        created_at: Time.zone.now,
      )

      picker = described_class.new(user: user, practice_mode: "unseen")
      expect(picker.pick).to eq(geo_q)
    end

    it "sets empty reason when everything was attempted" do
      [history_q, geo_q].each do |question|
        DiscourseQuiz::QuizUserAttempt.create!(
          user_id: user.id,
          question_id: question.id,
          answer_index: 0,
          is_correct: true,
          created_at: Time.zone.now,
        )
      end

      picker = described_class.new(user: user, practice_mode: "unseen")
      expect(picker.pick).to be_nil
      expect(picker.empty_reason).to eq(:no_unseen_questions)
    end
  end
end
