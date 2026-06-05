# frozen_string_literal: true

class AddScoreAwardedToQuizUserAttempts < ActiveRecord::Migration[7.0]
  def up
    return unless table_exists?(:discourse_quiz_user_attempts)
    return if column_exists?(:discourse_quiz_user_attempts, :score_awarded)

    add_column :discourse_quiz_user_attempts, :score_awarded, :boolean, default: false, null: false
    add_index :discourse_quiz_user_attempts, [:user_id, :score_awarded]
  end

  def down
    return unless table_exists?(:discourse_quiz_user_attempts)
    return unless column_exists?(:discourse_quiz_user_attempts, :score_awarded)

    remove_index :discourse_quiz_user_attempts, [:user_id, :score_awarded]
    remove_column :discourse_quiz_user_attempts, :score_awarded
  end
end
