# frozen_string_literal: true

require "rails_helper"

describe DiscourseGamifiedQuiz::QuizPointsService do
  let(:user) { Fabricate(:user) }
  let(:question) { 
    DiscourseGamifiedQuiz::QuizQuestion.create!(
      category_name: "General",
      question_text: "Test?",
      options: ["A", "B"],
      correct_index: 0
    )
  }
  let(:attempt) {
    DiscourseGamifiedQuiz::QuizUserAttempt.create!(
      user_id: user.id,
      question_id: question.id,
      is_correct: true
    )
  }

  before do
    SiteSetting.quiz_plugin_enabled = true
    SiteSetting.quiz_points_per_question = 10
    SiteSetting.quiz_daily_max_points = 100
  end

  describe ".award_points" do
    it "does not award points if gamification is not active" do
      expect(DiscourseGamifiedQuiz::QuizPointsService.award_points(user, question, attempt)).to be_nil
      expect(attempt.reload.score_awarded).to eq(false)
    end

    context "when gamification is active" do
      before do
        # Mocking gamification active
        allow(DiscourseGamifiedQuiz::QuizPointsService).to receive(:gamification_active?).and_return(true)
      end

      it "awards points and updates attempt" do
        # Mocking the actual award logic since we don't want to depend on the other plugin's DB state in this test
        allow(DiscourseGamifiedQuiz::QuizPointsService).to receive(:award_via_gamification).and_return(true)

        DiscourseGamifiedQuiz::QuizPointsService.award_points(user, question, attempt)
        expect(attempt.reload.score_awarded).to eq(true)
      end

      it "does not award points if daily limit is reached" do
        # Simulate 10 correct attempts today (10 * 10 = 100)
        10.times do |i|
          DiscourseGamifiedQuiz::QuizUserAttempt.create!(
            user_id: user.id,
            question_id: question.id + i + 1,
            is_correct: true,
            score_awarded: true,
            created_at: Time.zone.now
          )
        end

        DiscourseGamifiedQuiz::QuizPointsService.award_points(user, question, attempt)
        expect(attempt.reload.score_awarded).to eq(false)
      end

      it "does not award points if already awarded for this question" do
        # Simulate previous correct attempt with score awarded
        DiscourseGamifiedQuiz::QuizUserAttempt.create!(
          user_id: user.id,
          question_id: question.id,
          is_correct: true,
          score_awarded: true
        )

        DiscourseGamifiedQuiz::QuizPointsService.award_points(user, question, attempt)
        expect(attempt.reload.score_awarded).to eq(false)
      end
    end
  end
end
