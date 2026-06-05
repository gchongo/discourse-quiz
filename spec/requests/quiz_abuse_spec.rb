# frozen_string_literal: true

require "rails_helper"

describe DiscourseGamifiedQuiz::QuizController do
  let(:user) { Fabricate(:user) }
  let!(:question) { 
    DiscourseGamifiedQuiz::QuizQuestion.create!(
      category_name: "General",
      question_text: "Test?",
      options: ["A", "B"],
      correct_index: 0,
      active: true
    ) 
  }

  before do
    SiteSetting.quiz_plugin_enabled = true
    SiteSetting.quiz_submit_cooldown_seconds = 5
    RateLimiter.enable
  end

  after do
    RateLimiter.disable
  end

  describe "POST /quiz/submit" do
    it "enforces rate limiting" do
      sign_in(user)
      
      # First submission should succeed
      post "/quiz/submit.json", params: { question_id: question.id, answer_index: 0 }
      expect(response.status).to eq(200)

      # Immediate second submission should fail with 429
      post "/quiz/submit.json", params: { question_id: question.id, answer_index: 0 }
      expect(response.status).to eq(429)
    end

    it "works for guests with rate limiting" do
      # First submission
      post "/quiz/submit.json", params: { question_id: question.id, answer_index: 0 }, headers: { "REMOTE_ADDR" => "1.1.1.1" }
      expect(response.status).to eq(200)

      # Second submission from same IP
      post "/quiz/submit.json", params: { question_id: question.id, answer_index: 0 }, headers: { "REMOTE_ADDR" => "1.1.1.1" }
      expect(response.status).to eq(429)

      # Third submission from different IP should succeed
      post "/quiz/submit.json", params: { question_id: question.id, answer_index: 0 }, headers: { "REMOTE_ADDR" => "1.1.1.2" }
      expect(response.status).to eq(200)
    end
  end
end
