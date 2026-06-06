# frozen_string_literal: true

require "rails_helper"

describe DiscourseQuiz::QuestionExporter do
  let!(:question) do
    DiscourseQuiz::QuizQuestion.create!(
      category_name: "历史",
      question_text: "测试题",
      options: %w[A B C],
      correct_index: 1,
      explanation: "解析",
      active: true,
    )
  end

  it "exports JSON with ids" do
    data = described_class.to_json([question])
    expect(data.first[:id]).to eq(question.id)
    expect(data.first[:options]).to eq(%w[A B C])
  end

  it "exports CSV with pipe-separated options" do
    csv = described_class.to_csv([question])
    expect(csv).to include("id,category_name,question_text,options,correct_index,explanation,active")
    expect(csv).to include("A|B|C")
  end
end
