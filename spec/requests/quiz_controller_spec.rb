# frozen_string_literal: true

require "rails_helper"

describe DiscourseQuiz::QuizController do
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
    end
  end

  describe "GET /quiz/categories" do
    it "returns category names" do
      get "/quiz/categories.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["categories"]).to include("示例")
    end
  end
end
