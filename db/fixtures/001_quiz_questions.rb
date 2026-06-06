# frozen_string_literal: true

return if Rails.env.test?
return unless ActiveRecord::Base.connection.table_exists?(:discourse_quiz_questions)
return if DiscourseQuiz::QuizQuestion.exists?

DiscourseQuiz::QuizQuestion.create!(
  category_name: "示例",
  question_text: "1 + 1 = ?",
  options: %w[1 2 3],
  correct_index: 1,
  explanation: "基础算术：1 + 1 = 2。",
  active: true,
  position: 0,
)
