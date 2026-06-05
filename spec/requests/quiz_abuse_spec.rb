# frozen_string_literal: true

require "rails_helper"

describe DiscourseQuiz::QuizController do
  let(:user) { Fabricate(:user) }
  let!(:question) do
    DiscourseQuiz::QuizQuestion.create!(
      category_name: "General",
      question_text: "Test?",
      options: %w[A B],
      correct_index: 0,
      active: true,
    )
  end

  before do
    SiteSetting.quiz_plugin_enabled = true
    SiteSetting.quiz_submit_cooldown_seconds = 5
    RateLimiter.enable
  end

  after { RateLimiter.disable }

  describe "POST /quiz/submit" do
    it "enforces rate limiting without recording a second attempt" do
      sign_in(user)

      post "/quiz/submit.json", params: { question_id: question.id, answer_index: 0 }
      expect(response.status).to eq(200)
      expect(DiscourseQuiz::QuizUserAttempt.count).to eq(1)

      post "/quiz/submit.json", params: { question_id: question.id, answer_index: 0 }
      expect(response.status).to eq(429)
      expect(DiscourseQuiz::QuizUserAttempt.count).to eq(1)
    end

    it "works for guests with rate limiting" do
      post "/quiz/submit.json",
           params: {
             question_id: question.id,
             answer_index: 0,
           },
           headers: {
             "REMOTE_ADDR" => "1.1.1.1",
           }
      expect(response.status).to eq(200)

      post "/quiz/submit.json",
           params: {
             question_id: question.id,
             answer_index: 0,
           },
           headers: {
             "REMOTE_ADDR" => "1.1.1.1",
           }
      expect(response.status).to eq(429)

      post "/quiz/submit.json",
           params: {
             question_id: question.id,
             answer_index: 0,
           },
           headers: {
             "REMOTE_ADDR" => "1.1.1.2",
           }
      expect(response.status).to eq(200)
    end
  end
end
