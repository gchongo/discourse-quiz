# frozen_string_literal: true

class CreateDiscourseQuizUserAttempts < ActiveRecord::Migration[7.2]
  def up
    if table_exists?(:discourse_quiz_user_attempts)
      ensure_attempt_columns
      ensure_attempt_indexes
      return
    end

    create_table :discourse_quiz_user_attempts do |t|
      t.integer :user_id, null: false
      t.bigint :question_id, null: false
      t.integer :answer_index
      t.boolean :is_correct, null: false
      t.boolean :score_awarded, null: false, default: false
      t.datetime :created_at, null: false
    end

    ensure_attempt_indexes
  end

  def down
    drop_table :discourse_quiz_user_attempts, if_exists: true
  end

  private

  def ensure_attempt_columns
    return unless table_exists?(:discourse_quiz_user_attempts)

    unless column_exists?(:discourse_quiz_user_attempts, :answer_index)
      add_column :discourse_quiz_user_attempts, :answer_index, :integer
    end

    unless column_exists?(:discourse_quiz_user_attempts, :score_awarded)
      add_column :discourse_quiz_user_attempts,
                  :score_awarded,
                  :boolean,
                  null: false,
                  default: false
    end
  end

  def ensure_attempt_indexes
    return unless table_exists?(:discourse_quiz_user_attempts)

    add_index :discourse_quiz_user_attempts, %i[user_id question_id], if_not_exists: true
    add_index :discourse_quiz_user_attempts, :question_id, if_not_exists: true
    add_index :discourse_quiz_user_attempts, %i[user_id created_at], if_not_exists: true
  end
end
