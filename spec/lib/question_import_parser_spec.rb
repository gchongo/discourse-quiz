# frozen_string_literal: true

require "rails_helper"

describe DiscourseQuiz::QuestionImportParser do
  describe ".parse_json" do
    it "parses a valid JSON array" do
      payload = [
        {
          category_name: "历史",
          question_text: "测试题",
          options: %w[A B C],
          correct_index: 1,
        },
      ].to_json

      result = described_class.parse_json(payload)

      expect(result.length).to eq(1)
      expect(result.first["category_name"]).to eq("历史")
      expect(result.first["options"]).to eq(%w[A B C])
      expect(result.first["correct_index"]).to eq(1)
    end

    it "raises on invalid JSON" do
      expect { described_class.parse_json("{bad") }.to raise_error(
        described_class::ImportError,
      ) do |error|
        expect(error.key).to eq(:import_invalid_json)
      end
    end
  end

  describe ".parse_csv" do
    it "parses pipe-separated options" do
      payload = <<~CSV
        category_name,question_text,options,correct_index,explanation,active
        科学,2+2=?,1|2|3|4,1,基础算术,true
      CSV

      result = described_class.parse_csv(payload)

      expect(result.length).to eq(1)
      expect(result.first["category_name"]).to eq("科学")
      expect(result.first["options"]).to eq(%w[1 2 3 4])
      expect(result.first["correct_index"]).to eq(1)
      expect(result.first["active"]).to eq(true)
    end

    it "raises on invalid CSV" do
      expect { described_class.parse_csv('"unclosed') }.to raise_error(
        described_class::ImportError,
      ) do |error|
        expect(error.key).to eq(:import_invalid_csv)
      end
    end
  end
end
