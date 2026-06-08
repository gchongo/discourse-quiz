# frozen_string_literal: true

class AddPointsAwardedToQuizUserAttempts < ActiveRecord::Migration[7.2]
  def up
    return unless table_exists?(:discourse_quiz_user_attempts)
    return if column_exists?(:discourse_quiz_user_attempts, :points_awarded)

    add_column :discourse_quiz_user_attempts, :points_awarded, :integer, null: false, default: 0
  end

  def down
    return unless table_exists?(:discourse_quiz_user_attempts)
    return unless column_exists?(:discourse_quiz_user_attempts, :points_awarded)

    remove_column :discourse_quiz_user_attempts, :points_awarded
  end
end
