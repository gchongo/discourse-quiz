# frozen_string_literal: true

module DiscourseQuiz
  module SeedQuestions
    SAMPLE = {
      category_name: "示例",
      question_text: "1 + 1 = ?",
      options: %w[1 2 3],
      correct_index: 1,
      explanation: "基础算术：1 + 1 = 2。",
      active: true,
      position: 0,
    }.freeze

    def self.seed!
      return unless ActiveRecord::Base.connection.table_exists?(:discourse_quiz_questions)
      return if QuizQuestion.exists?

      QuizQuestion.create!(SAMPLE)
    end
  end
end
