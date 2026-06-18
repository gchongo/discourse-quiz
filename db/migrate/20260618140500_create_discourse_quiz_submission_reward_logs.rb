# frozen_string_literal: true

class CreateDiscourseQuizSubmissionRewardLogs < ActiveRecord::Migration[7.2]
  TABLE_NAME = :discourse_quiz_submission_reward_logs
  UNIQUE_INDEX = "idx_quiz_submission_reward_logs_unique_submission"

  def up
    create_logs_table
    ensure_indexes
  end

  def down
    drop_table TABLE_NAME, if_exists: true
  end

  private

  def create_logs_table
    return if table_exists?(TABLE_NAME)

    create_table TABLE_NAME do |t|
      t.integer :submission_id, null: false
      t.integer :user_id, null: false
      t.integer :points_awarded, null: false, default: 0
      t.date :awarded_on, null: false
      t.string :reason, null: false, default: "approved"
      t.timestamps
    end
  end

  def ensure_indexes
    add_index TABLE_NAME, :submission_id, unique: true, name: UNIQUE_INDEX, if_not_exists: true
    add_index TABLE_NAME, %i[user_id awarded_on], if_not_exists: true
    add_index TABLE_NAME, :created_at, if_not_exists: true
  end
end
