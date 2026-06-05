# frozen_string_literal: true

require "rails_helper"

describe Admin::Quiz::QuestionsController do
  let(:admin) { Fabricate(:admin) }
  let!(:question) do
    DiscourseQuiz::QuizQuestion.create!(
      category_name: "General",
      question_text: "Old text",
      options: ["A", "B"],
      correct_index: 0,
    )
  end

  before do
    SiteSetting.quiz_plugin_enabled = true
    sign_in(admin)
  end

  describe "#index" do
    it "returns list of questions" do
      get "/admin/quiz/questions.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["questions"].length).to eq(1)
    end
  end

  describe "#stats" do
    it "returns statistics" do
      get "/admin/quiz/stats.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["total_questions"]).to eq(1)
    end
  end

  describe "#create" do
    it "creates a new question" do
      post "/admin/quiz/questions.json",
           params: {
             question: {
               category_name: "NewCat",
               question_text: "New Question",
               options: %w[Opt1 Opt2],
               correct_index: 1,
               active: true,
             },
           }
      expect(response.status).to eq(200)
      expect(DiscourseQuiz::QuizQuestion.count).to eq(2)
    end
  end

  describe "#update" do
    it "updates existing question" do
      put "/admin/quiz/questions/#{question.id}.json",
          params: {
            question: {
              question_text: "Updated text",
            },
          }
      expect(response.status).to eq(200)
      expect(question.reload.question_text).to eq("Updated text")
    end
  end

  describe "#destroy" do
    it "deletes a question" do
      delete "/admin/quiz/questions/#{question.id}.json"
      expect(response.status).to eq(204)
      expect(DiscourseQuiz::QuizQuestion.count).to eq(0)
    end
  end
end
