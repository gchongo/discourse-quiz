# frozen_string_literal: true

class CreateDiscourseQuizUserAttempts < ActiveRecord::Migration[7.2]
  def up
    return if table_exists?(:discourse_quiz_user_attempts)

    create_table :discourse_quiz_user_attempts do |t|
      t.integer :user_id, null: false
      t.bigint :question_id, null: false
      t.integer :answer_index
      t.boolean :is_correct, null: false
      t.boolean :score_awarded, null: false, default: false
      t.datetime :created_at, null: false
    end

    add_index :discourse_quiz_user_attempts, %i[user_id question_id]
    add_index :discourse_quiz_user_attempts, :question_id
    add_index :discourse_quiz_user_attempts, %i[user_id created_at]
  end

  def down
    drop_table :discourse_quiz_user_attempts, if_exists: true
  end
end
