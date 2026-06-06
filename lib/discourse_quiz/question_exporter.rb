# frozen_string_literal: true

require "csv"

module DiscourseQuiz
  class QuestionExporter
    HEADERS = %w[
      id
      category_name
      question_text
      question_type
      options
      correct_index
      correct_indices
      explanation
      active
    ].freeze

    def self.to_json(questions)
      questions.map { |question| question_hash(question) }
    end

    def self.to_csv(questions)
      CSV.generate do |csv|
        csv << HEADERS
        questions.each { |question| csv << csv_row(question) }
      end
    end

    def self.question_hash(question)
      hash = {
        id: question.id,
        category_name: question.category_name,
        question_text: question.question_text,
        question_type: question.resolved_question_type,
        options: question.options,
        correct_index: question.correct_index,
        correct_indices: question.multiple_choice? ? question.resolved_correct_indices : [],
        explanation: question.explanation,
        active: question.active,
      }
      hash[:position] = question.position if question.respond_to?(:position) && QuizQuestion.position_column?
      hash
    end

    def self.csv_row(question)
      [
        question.id,
        question.category_name,
        question.question_text,
        question.resolved_question_type,
        Array(question.options).join("|"),
        question.correct_index,
        Array(question.resolved_correct_indices).join("|"),
        question.explanation,
        question.active,
      ]
    end
  end
end
