# frozen_string_literal: true

class AddForeignKeysToQuizTables < ActiveRecord::Migration[7.0]
  def up
    return unless table_exists?(:discourse_quiz_user_attempts)
    return unless table_exists?(:discourse_quiz_questions)

    execute <<~SQL
      DELETE FROM discourse_quiz_user_attempts
      WHERE user_id NOT IN (SELECT id FROM users)
         OR question_id NOT IN (SELECT id FROM discourse_quiz_questions)
    SQL

    unless foreign_key_exists?(:discourse_quiz_user_attempts, column: :user_id)
      add_foreign_key :discourse_quiz_user_attempts, :users, column: :user_id
    end

    unless foreign_key_exists?(:discourse_quiz_user_attempts, column: :question_id)
      add_foreign_key :discourse_quiz_user_attempts,
                      :discourse_quiz_questions,
                      column: :question_id
    end
  end

  def down
    return unless table_exists?(:discourse_quiz_user_attempts)

    if foreign_key_exists?(:discourse_quiz_user_attempts, column: :user_id)
      remove_foreign_key :discourse_quiz_user_attempts, column: :user_id
    end

    if foreign_key_exists?(:discourse_quiz_user_attempts, column: :question_id)
      remove_foreign_key :discourse_quiz_user_attempts, column: :question_id
    end
  end
end
