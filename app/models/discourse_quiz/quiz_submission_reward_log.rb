# frozen_string_literal: true

module DiscourseQuiz
  class QuizSubmissionRewardLog < ::ActiveRecord::Base
    self.table_name = "discourse_quiz_submission_reward_logs"

    validates :submission_id, presence: true, uniqueness: true
    validates :user_id, presence: true
    validates :awarded_on, presence: true
    validates :points_awarded, numericality: { greater_than_or_equal_to: 0 }
  end
end
