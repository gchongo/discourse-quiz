# frozen_string_literal: true

require "rails_helper"

describe DiscourseQuiz::QuizStatusService do
  before { SiteSetting.quiz_guest_attempt_limit = 2 }

  describe "guest status" do
    it "returns attempts left" do
      status = described_class.new(nil, 1).get_status
      expect(status[:is_guest]).to eq(true)
      expect(status[:attempts_left]).to eq(1)
      expect(status[:mode]).to eq("normal")
    end

    it "enters paywall when limit reached" do
      status = described_class.new(nil, 2).get_status
      expect(status[:mode]).to eq("paywall")
      expect(status[:attempts_left]).to eq(0)
    end
  end

  describe "logged in status" do
    let(:user) { Fabricate(:user) }

    it "enters learning only when daily max reached" do
      SiteSetting.quiz_daily_max_points = 10
      SiteSetting.quiz_points_per_question = 10

      question = DiscourseQuiz::QuizQuestion.create!(
        category_name: "示例",
        question_text: "Q",
        options: %w[A B],
        correct_index: 0,
      )

      DiscourseQuiz::QuizUserAttempt.create!(
        user_id: user.id,
        question_id: question.id,
        answer_index: 0,
        is_correct: true,
        score_awarded: true,
        created_at: Time.zone.now,
      )

      status = described_class.new(user, 0).get_status
      expect(status[:mode]).to eq("learning_only")
      expect(status[:daily_max_reached]).to eq(true)
    end

    it "includes practice stats" do
      status = described_class.new(user, 0).get_status
      expect(status[:stats]).to be_present
      expect(status[:stats]).to have_key(:wrong_pending)
      expect(status[:stats]).to have_key(:unseen_pending)
    end
  end
end
