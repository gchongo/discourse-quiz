# frozen_string_literal: true

require "rails_helper"

describe DiscourseQuiz::QuizController do
  let(:user) { Fabricate(:user) }
  let!(:question) do
    DiscourseQuiz::QuizQuestion.create!(
      category_name: "General",
      question_text: "What is 1+1?",
      options: %w[1 2 3],
      correct_index: 1,
      explanation: "Basic math explanation.",
      active: true,
    )
  end

  before { SiteSetting.quiz_plugin_enabled = true }

  describe "GET /quiz/next" do
    it "returns the next question without sensitive data" do
      get "/quiz/next.json"
      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["id"]).to eq(question.id)
      expect(json["question_text"]).to eq(question.question_text)
      expect(json).not_to have_key("correct_index")
      expect(json).not_to have_key("explanation")
    end

    it "returns 404 when no active questions" do
      question.update!(active: false)
      get "/quiz/next.json"
      expect(response.status).to eq(404)
    end

    it "returns 403 when guest paywall is reached" do
      SiteSetting.quiz_guest_attempt_limit = 1
      post "/quiz/submit.json", params: { question_id: question.id, answer_index: 0 }

      get "/quiz/next.json"
      expect(response.status).to eq(403)
    end
  end

  describe "POST /quiz/submit" do
    it "returns correct: true and full explanation for logged-in user" do
      sign_in(user)
      post "/quiz/submit.json", params: { question_id: question.id, answer_index: 1 }
      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["correct"]).to eq(true)
      expect(json["explanation"]).to eq(question.explanation)
    end

    it "returns correct: false and no explanation for wrong answer" do
      sign_in(user)
      post "/quiz/submit.json", params: { question_id: question.id, answer_index: 0 }
      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["correct"]).to eq(false)
      expect(json).not_to have_key("explanation")
    end

    it "masks explanation for guests" do
      post "/quiz/submit.json", params: { question_id: question.id, answer_index: 1 }
      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["correct"]).to eq(true)
      expect(json["explanation"]).to include(
        I18n.t("gamified_quiz.guest_explanation_masked_suffix"),
      )
    end

    it "returns 404 for inactive questions" do
      question.update!(active: false)
      sign_in(user)
      post "/quiz/submit.json", params: { question_id: question.id, answer_index: 1 }
      expect(response.status).to eq(404)
    end

    it "returns 422 for invalid answer index" do
      sign_in(user)
      post "/quiz/submit.json", params: { question_id: question.id, answer_index: 99 }
      expect(response.status).to eq(422)
    end
  end

  describe "GET /quiz/status" do
    it "returns logged-in status" do
      sign_in(user)
      get "/quiz/status.json"
      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["is_guest"]).to eq(false)
      expect(json["mode"]).to eq("normal")
    end
  end
end
