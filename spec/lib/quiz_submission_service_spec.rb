# frozen_string_literal: true

require "rails_helper"

describe DiscourseQuiz::QuizSubmissionService do
  let(:user) { Fabricate(:user) }

  let!(:single_question) do
    DiscourseQuiz::QuizQuestion.create!(
      category_name: "历史",
      question_text: "Single?",
      options: %w[A B C],
      correct_index: 1,
      question_type: "single_choice",
    )
  end

  let!(:true_false_question) do
    DiscourseQuiz::QuizQuestion.create!(
      category_name: "历史",
      question_text: "TF?",
      question_type: "true_false",
      options: %w[True False],
      correct_index: 0,
    )
  end

  let!(:multiple_question) do
    DiscourseQuiz::QuizQuestion.create!(
      category_name: "历史",
      question_text: "Multiple?",
      question_type: "multiple_choice",
      options: %w[A B C D],
      correct_index: 0,
      correct_indices: [0, 2],
    )
  end

  it "grades single-choice answers" do
    result =
      described_class.new(user, single_question, answer_index: 1).submit

    expect(result[:correct]).to eq(true)
    expect(result[:correct_option]).to eq("B")
  end

  it "grades true/false answers" do
    result =
      described_class.new(user, true_false_question, answer_index: 0).submit

    expect(result[:correct]).to eq(true)
    expect(result[:question_type]).to eq("true_false")
  end

  it "requires all correct options for multiple-choice answers" do
    correct =
      described_class.new(user, multiple_question, answer_indices: [0, 2]).submit
    partial =
      described_class.new(user, multiple_question, answer_indices: [0]).submit
    wrong =
      described_class.new(user, multiple_question, answer_indices: [0, 1]).submit

    expect(correct[:correct]).to eq(true)
    expect(correct[:correct_options]).to eq(%w[A C])
    expect(partial[:correct]).to eq(false)
    expect(wrong[:correct]).to eq(false)
  end

  it "rejects invalid multiple-choice submissions" do
    submission = described_class.new(user, multiple_question, answer_indices: [])
    result = submission.submit

    expect(submission.failed?).to eq(true)
    expect(result[:error]).to be_present
  end
end
