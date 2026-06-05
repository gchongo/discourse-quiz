# frozen_string_literal: true

module DiscourseQuiz
  class QuizUserAttempt < ::ActiveRecord::Base
    self.table_name = "discourse_quiz_user_attempts"

    validates :user_id, presence: true
    validates :question_id, presence: true
    validates :is_correct, inclusion: { in: [true, false] }

    belongs_to :user
    belongs_to :question,
               class_name: "DiscourseQuiz::QuizQuestion",
               foreign_key: "question_id"

    scope :awarded_today,
          ->(user_id) {
            where(user_id: user_id, is_correct: true, score_awarded: true).where(
              "created_at > ?",
              Time.zone.now.beginning_of_day,
            )
          }
  end
end
