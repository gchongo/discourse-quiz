# frozen_string_literal: true

require "rails_helper"

describe DiscourseQuiz::PointsAwarder do
  let(:user) { Fabricate(:user) }
  let(:question) do
    DiscourseQuiz::QuizQuestion.create!(
      category_name: "General",
      question_text: "Test?",
      options: ["A", "B"],
      correct_index: 0,
    )
  end
  let(:attempt) do
    DiscourseQuiz::QuizUserAttempt.create!(
      user_id: user.id,
      question_id: question.id,
      is_correct: true,
    )
  end

  before do
    SiteSetting.quiz_plugin_enabled = true
    SiteSetting.quiz_points_per_question = 10
    SiteSetting.quiz_daily_max_points = 100
  end

  describe ".call" do
    subject(:result) { described_class.call(params: { user:, question:, attempt: }) }

    it "does not award points if gamification is not active" do
      expect(result).to run_successfully
      expect(attempt.reload.score_awarded).to eq(false)
    end

    context "when gamification is active" do
      before do
        allow_any_instance_of(described_class).to receive(:gamification_active?).and_return(true)
        allow_any_instance_of(described_class).to receive(:create_gamification_event).and_return(true)
      end

      it "awards points and updates attempt" do
        expect(result).to run_successfully
        expect(attempt.reload.score_awarded).to eq(true)
      end

      it "does not award points if daily limit is reached" do
        10.times do |i|
          DiscourseQuiz::QuizUserAttempt.create!(
            user_id: user.id,
            question_id: question.id + i + 1,
            is_correct: true,
            score_awarded: true,
            created_at: Time.zone.now,
          )
        end

        expect(result).to fail_a_step(:validate_daily_limit_not_reached)
        expect(attempt.reload.score_awarded).to eq(false)
      end

      it "does not award points if already awarded for this question" do
        DiscourseQuiz::QuizUserAttempt.create!(
          user_id: user.id,
          question_id: question.id,
          is_correct: true,
          score_awarded: true,
        )

        expect(result).to fail_a_step(:validate_not_already_awarded)
        expect(attempt.reload.score_awarded).to eq(false)
      end
    end
  end
end
