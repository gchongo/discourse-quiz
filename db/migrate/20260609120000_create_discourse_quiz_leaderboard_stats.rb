# frozen_string_literal: true

class CreateDiscourseQuizLeaderboardStats < ActiveRecord::Migration[7.2]
  def up
    return if table_exists?(:discourse_quiz_leaderboard_stats)

    create_table :discourse_quiz_leaderboard_stats do |t|
      t.integer :user_id, null: false
      t.string :category_name, null: false, default: ""
      t.integer :questions_attempted, null: false, default: 0
      t.integer :questions_correct, null: false, default: 0
      t.float :accuracy_rate
      t.datetime :updated_at, null: false
    end

    add_index :discourse_quiz_leaderboard_stats,
              %i[user_id category_name],
              unique: true,
              name: "idx_quiz_leaderboard_stats_user_category"
    add_index :discourse_quiz_leaderboard_stats,
              %i[category_name questions_attempted],
              name: "idx_quiz_leaderboard_stats_volume"
    add_index :discourse_quiz_leaderboard_stats,
              %i[category_name accuracy_rate questions_attempted],
              name: "idx_quiz_leaderboard_stats_accuracy"
  end

  def down
    drop_table :discourse_quiz_leaderboard_stats, if_exists: true
  end
end
