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
      expect(described_class.pick_random(category_name: "历史")).to eq(history)
      expect(described_class.pick_random(category_name: "科学")).to be_nil
    end
  end
end
