# frozen_string_literal: true

require "rails_helper"

describe DiscourseQuiz::AdminQuizQuestionsController do
  let(:admin) { Fabricate(:admin) }

  before do
    SiteSetting.quiz_plugin_enabled = true
    sign_in(admin)
  end

  describe "POST /admin/quiz/questions" do
    it "creates a question" do
      post "/admin/quiz/questions.json",
           params: {
             question: {
               category_name: "历史",
               question_text: "新题目",
               options: %w[A B C],
               correct_index: 1,
               explanation: "解析",
               active: true,
             },
           }

      expect(response.status).to eq(200)
      expect(DiscourseQuiz::QuizQuestion.count).to eq(1)
      expect(response.parsed_body["question"]["question_text"]).to eq("新题目")
    end

    it "returns a duplicate warning when question text already exists" do
      existing =
        DiscourseQuiz::QuizQuestion.create!(
          category_name: "历史",
          question_text: "已有题目",
          options: %w[A B],
          correct_index: 0,
        )

      post "/admin/quiz/questions.json",
           params: {
             question: {
               category_name: "地理",
               question_text: "已有题目",
               options: %w[A B C],
               correct_index: 1,
               active: true,
             },
           }

      expect(response.status).to eq(200)
      expect(response.parsed_body["duplicate_warning"]["duplicate_ids"]).to contain_exactly(
        existing.id,
      )
    end
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

    it "supports dry run without saving" do
      payload = [
        {
          category_name: "历史",
          question_text: "测试题",
          options: %w[A B],
          correct_index: 0,
        },
      ].to_json

      post "/admin/quiz/questions/bulk_import.json",
           params: {
             questions_json: payload,
             dry_run: true,
           }

      expect(response.status).to eq(200)
      expect(response.parsed_body["dry_run"]).to eq(true)
      expect(response.parsed_body["valid"]).to eq(1)
      expect(DiscourseQuiz::QuizQuestion.count).to eq(0)
    end

    it "returns duplicate warnings for repeated import rows and existing questions" do
      existing =
        DiscourseQuiz::QuizQuestion.create!(
          category_name: "历史",
          question_text: "重复题干",
          options: %w[A B],
          correct_index: 0,
        )

      payload = [
        {
          category_name: "历史",
          question_text: "本批重复",
          options: %w[A B],
          correct_index: 0,
        },
        {
          category_name: "地理",
          question_text: "本批重复",
          options: %w[A B C],
          correct_index: 1,
        },
        {
          category_name: "常识",
          question_text: "重复题干",
          options: %w[X Y],
          correct_index: 0,
        },
      ].to_json

      post "/admin/quiz/questions/bulk_import.json", params: { questions_json: payload }

      body = response.parsed_body
      expect(response.status).to eq(200)
      expect(body["imported"]).to eq(3)
      expect(body["warnings"].length).to eq(2)

      batch_warning = body["warnings"].find { |warning| warning["row"] == 2 }
      existing_warning = body["warnings"].find { |warning| warning["row"] == 3 }

      expect(batch_warning["message"]).to include("1")
      expect(existing_warning["message"]).to include(existing.id.to_s)
    end

    it "supports upsert by id" do
      question =
        DiscourseQuiz::QuizQuestion.create!(
          category_name: "科学",
          question_text: "旧题目",
          options: %w[A B],
          correct_index: 0,
        )

      payload = [
        {
          id: question.id,
          category_name: "历史",
          question_text: "更新题目",
          options: %w[X Y],
          correct_index: 1,
        },
      ].to_json

      post "/admin/quiz/questions/bulk_import.json",
           params: { questions_json: payload, upsert: true }

      expect(response.status).to eq(200)
      expect(response.parsed_body["updated"]).to eq(1)
      expect(DiscourseQuiz::QuizQuestion.count).to eq(1)
      expect(question.reload.question_text).to eq("更新题目")
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
    it "returns questions and categories with pagination metadata" do
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
      expect(response.parsed_body["total"]).to eq(1)
    end

    it "filters by search query" do
      DiscourseQuiz::QuizQuestion.create!(
        category_name: "科学",
        question_text: "苹果是什么颜色",
        options: %w[A B],
        correct_index: 0,
      )
      DiscourseQuiz::QuizQuestion.create!(
        category_name: "历史",
        question_text: "秦朝何时统一",
        options: %w[A B],
        correct_index: 0,
      )

      get "/admin/quiz/questions.json", params: { q: "苹果" }
      expect(response.parsed_body["questions"].length).to eq(1)
      expect(response.parsed_body["questions"].first["question_text"]).to include("苹果")
    end

    it "filters by question_type" do
      single =
        DiscourseQuiz::QuizQuestion.create!(
          category_name: "历史",
          question_text: "单选题",
          question_type: "single_choice",
          options: %w[A B],
          correct_index: 0,
        )

      DiscourseQuiz::QuizQuestion.create!(
        category_name: "历史",
        question_text: "多选题",
        question_type: "multiple_choice",
        options: %w[A B C],
        correct_index: 0,
        correct_indices: [0, 1],
      )

      get "/admin/quiz/questions.json", params: { question_type: "single_choice" }
      expect(response.parsed_body["questions"].length).to eq(1)
      expect(response.parsed_body["questions"].first["id"]).to eq(single.id)
    end

    it "bulk disables duplicate questions" do
      kept =
        DiscourseQuiz::QuizQuestion.create!(
          category_name: "历史",
          question_text: "重复题干",
          options: %w[A B],
          correct_index: 0,
        )

      duplicate =
        DiscourseQuiz::QuizQuestion.create!(
          category_name: "地理",
          question_text: "  重复题干 ",
          options: %w[A B C],
          correct_index: 1,
        )

      post "/admin/quiz/questions/bulk_disable_duplicates.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["disabled"]).to eq(1)
      expect(response.parsed_body["kept_ids"]).to contain_exactly(kept.id)
      expect(kept.reload.active).to eq(true)
      expect(duplicate.reload.active).to eq(false)
    end

    it "returns duplicate summary and flags duplicate questions" do
      first =
        DiscourseQuiz::QuizQuestion.create!(
          category_name: "历史",
          question_text: "重复题干",
          options: %w[A B],
          correct_index: 0,
        )

      duplicate =
        DiscourseQuiz::QuizQuestion.create!(
          category_name: "地理",
          question_text: "  重复题干 ",
          options: %w[A B C],
          correct_index: 1,
        )

      get "/admin/quiz/questions.json"
      body = response.parsed_body

      expect(body["duplicate_summary"]["duplicate_group_count"]).to eq(1)
      expect(body["duplicate_summary"]["duplicate_question_count"]).to eq(2)

      flagged = body["questions"].find { |q| q["id"] == duplicate.id }
      expect(flagged["duplicate_ids"]).to contain_exactly(first.id)
      expect(flagged["duplicate_count"]).to eq(2)
    end
  end

  describe "GET /admin/quiz/questions/export" do
    it "exports JSON" do
      question =
        DiscourseQuiz::QuizQuestion.create!(
          category_name: "科学",
          question_text: "Q",
          options: %w[A B],
          correct_index: 0,
        )

      get "/admin/quiz/questions/export.json", params: { export_format: "json" }
      expect(response.status).to eq(200)
      expect(response.parsed_body["data"].first["id"]).to eq(question.id)
    end

    it "exports CSV" do
      DiscourseQuiz::QuizQuestion.create!(
        category_name: "科学",
        question_text: "Q",
        options: %w[A B],
        correct_index: 0,
      )

      get "/admin/quiz/questions/export.json", params: { export_format: "csv" }
      expect(response.status).to eq(200)
      expect(response.parsed_body["data"]).to include("category_name")
    end
  end

  describe "PUT /admin/quiz/categories/rename" do
    it "renames a category across questions" do
      DiscourseQuiz::QuizQuestion.create!(
        category_name: "旧分类",
        question_text: "Q1",
        options: %w[A B],
        correct_index: 0,
      )
      DiscourseQuiz::QuizQuestion.create!(
        category_name: "旧分类",
        question_text: "Q2",
        options: %w[A B],
        correct_index: 0,
      )

      put "/admin/quiz/categories/rename.json",
          params: { from_name: "旧分类", to_name: "新分类" }

      expect(response.status).to eq(200)
      expect(response.parsed_body["updated"]).to eq(2)
      expect(DiscourseQuiz::QuizQuestion.pluck(:category_name).uniq).to eq(["新分类"])
    end
  end
end
