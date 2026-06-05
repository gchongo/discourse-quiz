# frozen_string_literal: true

require "rails_helper"

describe Admin::GamifiedQuiz::QuestionsController do
  let(:admin) { Fabricate(:admin) }
  let!(:question) { 
    DiscourseGamifiedQuiz::QuizQuestion.create!(
      category_name: "General",
      question_text: "Old text",
      options: ["A", "B"],
      correct_index: 0
    ) 
  }

  before do
    sign_in(admin)
  end

  describe "#index" do
    it "returns list of questions" do
      get "/admin/gamified_quiz/questions.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["questions"].length).to eq(1)
    end
  end

  describe "#stats" do
    it "returns statistics" do
      get "/admin/gamified_quiz/stats.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["total_questions"]).to eq(1)
    end
  end

  describe "#create" do
    it "creates a new question" do
      post "/admin/gamified_quiz/questions.json", params: {
        question: {
          category_name: "NewCat",
          question_text: "New Question",
          options: ["Opt1", "Opt2"],
          correct_index: 1,
          active: true
        }
      }
      expect(response.status).to eq(200)
      expect(DiscourseGamifiedQuiz::QuizQuestion.count).to eq(2)
    end
  end

  describe "#update" do
    it "updates existing question" do
      put "/admin/gamified_quiz/questions.json/#{question.id}", params: {
        question: {
          question_text: "Updated text"
        }
      }
      expect(response.status).to eq(200)
      expect(question.reload.question_text).to eq("Updated text")
    end
  end

  describe "#destroy" do
    it "deletes a question" do
      delete "/admin/gamified_quiz/questions.json/#{question.id}"
      expect(response.status).to eq(200)
      expect(DiscourseGamifiedQuiz::QuizQuestion.count).to eq(0)
    end
  end
end
