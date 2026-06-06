# frozen_string_literal: true

require "rails_helper"

describe DiscourseQuiz::QuizController do
  let(:user) { Fabricate(:user) }

  let!(:question) do
    DiscourseQuiz::QuizQuestion.create!(
      category_name: "示例",
      question_text: "1 + 1 = ?",
      options: %w[1 2 3],
      correct_index: 1,
    )
  end

  before { SiteSetting.quiz_plugin_enabled = true }

  describe "GET /quiz/next" do
    it "returns a question without the answer" do
      get "/quiz/next.json"
      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["question_text"]).to eq(question.question_text)
      expect(json).not_to have_key("correct_index")
      expect(json["status"]).to be_present
    end

    it "filters by category_name param" do
      DiscourseQuiz::QuizQuestion.create!(
        category_name: "体育",
        question_text: "马拉松?",
        options: %w[A B],
        correct_index: 0,
      )

      get "/quiz/next.json", params: { category_name: "体育" }
      expect(response.status).to eq(200)
      expect(response.parsed_body["category_name"]).to eq("体育")
    end

    it "filters by multiple category_names params" do
      DiscourseQuiz::QuizQuestion.create!(
        category_name: "体育",
        question_text: "马拉松?",
        options: %w[A B],
        correct_index: 0,
      )

      get "/quiz/next.json", params: { category_names: %w[体育 示例] }
      expect(response.status).to eq(200)
      expect(%w[体育 示例]).to include(response.parsed_body["category_name"])
    end

    it "returns paywall for guests over the limit" do
      SiteSetting.quiz_guest_attempt_limit = 1

      get "/quiz/next.json", session: { quiz_guest_attempts: 1 }
      expect(response.status).to eq(403)
      expect(response.parsed_body["status"]["mode"]).to eq("paywall")
    end

    it "requires login for wrong_only practice mode" do
      get "/quiz/next.json", params: { practice_mode: "wrong_only" }
      expect(response.status).to eq(403)
      expect(response.parsed_body["error_code"]).to eq("practice_mode_requires_login")
    end

    it "returns wrong-only questions for logged in users" do
      sign_in(user)

      DiscourseQuiz::QuizUserAttempt.create!(
        user_id: user.id,
        question_id: question.id,
        answer_index: 0,
        is_correct: false,
        created_at: Time.zone.now,
      )

      get "/quiz/next.json", params: { practice_mode: "wrong_only" }
      expect(response.status).to eq(200)
      expect(response.parsed_body["id"]).to eq(question.id)
    end

    it "returns unseen questions for logged in users" do
      sign_in(user)

      other =
        DiscourseQuiz::QuizQuestion.create!(
          category_name: "体育",
          question_text: "Marathon?",
          options: %w[A B],
          correct_index: 0,
        )

      DiscourseQuiz::QuizUserAttempt.create!(
        user_id: user.id,
        question_id: question.id,
        answer_index: 1,
        is_correct: true,
        created_at: Time.zone.now,
      )

      get "/quiz/next.json", params: { practice_mode: "unseen" }
      expect(response.status).to eq(200)
      expect(response.parsed_body["id"]).to eq(other.id)
    end
  end

  describe "GET /quiz/status" do
    it "returns quiz status" do
      get "/quiz/status.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["is_guest"]).to eq(true)
    end
  end

  describe "GET /quiz/summary_stats" do
    it "requires login" do
      get "/quiz/summary_stats.json"
      expect(response.status).to eq(403)
    end

    it "returns quiz summary stats for the current user" do
      sign_in(user)

      DiscourseQuiz::QuizUserAttempt.create!(
        user_id: user.id,
        question_id: question.id,
        answer_index: 0,
        is_correct: false,
        created_at: Time.zone.now,
      )

      get "/quiz/summary_stats.json"
      expect(response.status).to eq(200)

      stats = response.parsed_body["quiz_summary_stats"]
      expect(stats["today_correct"]).to eq(0)
      expect(stats["today_incorrect"]).to eq(1)
      expect(stats["wrong_pending"]).to eq(1)
    end
  end

  describe "GET /quiz/categories" do
    it "returns active category names with status" do
      get "/quiz/categories.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["categories"]).to include("示例")
      expect(response.parsed_body["status"]).to be_present
    end

    it "respects the quiz_categories site setting allowlist" do
      DiscourseQuiz::QuizQuestion.create!(
        category_name: "体育",
        question_text: "Q2",
        options: %w[A B],
        correct_index: 0,
      )

      SiteSetting.quiz_categories = "体育"

      get "/quiz/categories.json"
      expect(response.parsed_body["categories"]).to eq(["体育"])
    end
  end

  describe "POST /quiz/submit" do
    it "returns correct for the right answer" do
      post "/quiz/submit.json", params: { question_id: question.id, answer_index: 1 }
      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["correct"]).to eq(true)
      expect(json["correct_index"]).to eq(1)
      expect(json["correct_option"]).to eq("2")
      expect(json["status"]).to be_present
    end

    it "records attempts for logged in users" do
      sign_in(user)

      expect {
        post "/quiz/submit.json", params: { question_id: question.id, answer_index: 1 }
      }.to change { DiscourseQuiz::QuizUserAttempt.count }.by(1)

      expect(response.parsed_body["correct"]).to eq(true)
    end

    it "increments guest attempt count in session" do
      post "/quiz/submit.json", params: { question_id: question.id, answer_index: 1 }
      expect(session[:quiz_guest_attempts]).to eq(1)
    end

    it "returns incorrect for the wrong answer" do
      post "/quiz/submit.json", params: { question_id: question.id, answer_index: 0 }
      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["correct"]).to eq(false)
      expect(json["correct_option"]).to eq("2")
    end

    it "rejects an invalid answer index" do
      post "/quiz/submit.json", params: { question_id: question.id, answer_index: 99 }
      expect(response.status).to eq(422)
    end

    it "returns not found for missing questions" do
      post "/quiz/submit.json", params: { question_id: -1, answer_index: 0 }
      expect(response.status).to eq(404)
    end
  end
end
