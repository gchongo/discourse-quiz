# frozen_string_literal: true

require "rails_helper"

describe DiscourseQuiz::QuizQuestion do
  describe ".pick_random" do
    let!(:history) do
      described_class.create!(
        category_name: "历史",
        question_text: "Q1",
        options: %w[A B],
        correct_index: 0,
      )
    end

    let!(:science) do
      described_class.create!(
        category_name: "科学",
        question_text: "Q2",
        options: %w[A B],
        correct_index: 1,
        active: false,
      )
    end

    it "returns an active question" do
      expect(described_class.pick_random).to eq(history)
    end

    it "filters by category" do
      expect(described_class.pick_random(category_names: ["历史"])).to eq(history)
      expect(described_class.pick_random(category_names: ["科学"])).to be_nil
    end
  end

  describe "question types" do
    it "normalizes true/false options from locale" do
      question =
        described_class.create!(
          category_name: "历史",
          question_text: "TF?",
          question_type: "true_false",
          options: %w[wrong],
          correct_index: 1,
        )

      expect(question.options).to eq(
        [
          I18n.t("discourse_quiz.true_false.true"),
          I18n.t("discourse_quiz.true_false.false"),
        ],
      )
      expect(question.correct_index).to eq(1)
    end

    it "validates multiple-choice correct indices" do
      question =
        described_class.new(
          category_name: "历史",
          question_text: "MC?",
          question_type: "multiple_choice",
          options: %w[A B C],
          correct_indices: [0, 2],
          correct_index: 0,
        )

      expect(question).to be_valid
      expect(question.graded_correct?(answer_indices: [0, 2])).to eq(true)
      expect(question.graded_correct?(answer_indices: [0, 1])).to eq(false)
    end
  end
end
