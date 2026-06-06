# frozen_string_literal: true

require "rails_helper"

describe DiscourseQuiz::AdminQuizQuestionsController do
  let(:admin) { Fabricate(:admin) }

  before do
    SiteSetting.quiz_plugin_enabled = true
    sign_in(admin)
  end

  describe "POST /admin/quiz/questions/bulk_import" do
    it "imports questions from JSON" do
      payload = [
        {
          category_name: "历史",
          question_text: "测试题",
          options: %w[A B],
          correct_index: 0,
        },
      ].to_json

      post "/admin/quiz/questions/bulk_import.json", params: { questions_json: payload }
      expect(response.status).to eq(200)
      expect(response.parsed_body["imported"]).to eq(1)
      expect(DiscourseQuiz::QuizQuestion.count).to eq(1)
    end
  end

  describe "GET /admin/quiz/questions" do
    it "returns questions and categories" do
      DiscourseQuiz::QuizQuestion.create!(
        category_name: "科学",
        question_text: "Q",
        options: %w[A B],
        correct_index: 0,
      )

      get "/admin/quiz/questions.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["questions"].length).to eq(1)
      expect(response.parsed_body["categories"]).to include("科学")
    end
  end
end
