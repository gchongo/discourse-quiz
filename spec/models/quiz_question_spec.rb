# frozen_string_literal: true

require "rails_helper"

describe DiscourseQuiz::QuizQuestion do
  it "is valid with valid attributes" do
    question = DiscourseQuiz::QuizQuestion.new(
      category_name: "General",
      question_text: "What is 1+1?",
      options: ["1", "2", "3"],
      correct_index: 1
    )
    expect(question).to be_valid
  end

  it "is invalid without question_text" do
    question = DiscourseQuiz::QuizQuestion.new(
      category_name: "General",
      options: ["1", "2"],
      correct_index: 0
    )
    expect(question).not_to be_valid
  end

  it "is invalid with empty options" do
    question = DiscourseQuiz::QuizQuestion.new(
      category_name: "General",
      question_text: "Test",
      options: [],
      correct_index: 0
    )
    expect(question).not_to be_valid
  end

  it "is invalid if correct_index is out of bounds" do
    question = DiscourseQuiz::QuizQuestion.new(
      category_name: "General",
      question_text: "Test",
      options: ["A", "B"],
      correct_index: 2
    )
    expect(question).not_to be_valid
  end
end
