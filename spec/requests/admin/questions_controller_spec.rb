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

  describe "PUT /admin/quiz/questions/:id" do
    let!(:question) do
      DiscourseQuiz::QuizQuestion.create!(
        category_name: "科学",
        question_text: "旧题目",
        options: %w[A B],
        correct_index: 0,
      )
    end

    it "updates a question" do
      put "/admin/quiz/questions/#{question.id}.json",
          params: {
            question: {
              category_name: "历史",
              question_text: "新题目",
              options: %w[X Y Z],
              correct_index: 2,
              explanation: "更新后的解析",
              active: false,
            },
          }

      expect(response.status).to eq(200)
      question.reload
      expect(question.category_name).to eq("历史")
      expect(question.question_text).to eq("新题目")
      expect(question.options).to eq(%w[X Y Z])
      expect(question.correct_index).to eq(2)
      expect(question.active).to eq(false)
    end

    it "returns validation errors" do
      put "/admin/quiz/questions/#{question.id}.json",
          params: {
            question: {
              category_name: "",
              question_text: "",
              options: [],
              correct_index: 0,
            },
          }

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to be_present
    end
  end

  describe "POST /admin/quiz/questions/bulk_import csv" do
    it "imports questions from CSV" do
      payload = <<~CSV
        category_name,question_text,options,correct_index
        历史,测试题,A|B,0
      CSV

      post "/admin/quiz/questions/bulk_import.json",
           params: { questions_json: payload, import_format: "csv" }

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
