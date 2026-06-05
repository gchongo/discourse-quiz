# frozen_string_literal: true

class AddScoreAwardedToQuizUserAttempts < ActiveRecord::Migration[7.0]
  def change
    add_column :discourse_quiz_user_attempts, :score_awarded, :boolean, default: false, null: false
    add_index :discourse_quiz_user_attempts, [:user_id, :score_awarded]
  end
end
