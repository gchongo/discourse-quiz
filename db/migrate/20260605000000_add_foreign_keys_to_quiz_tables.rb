# frozen_string_literal: true

class AddForeignKeysToQuizTables < ActiveRecord::Migration[7.0]
  def change
    add_foreign_key :discourse_quiz_user_attempts, :users, column: :user_id
    add_foreign_key :discourse_quiz_user_attempts,
                    :discourse_quiz_questions,
                    column: :question_id
  end
end
