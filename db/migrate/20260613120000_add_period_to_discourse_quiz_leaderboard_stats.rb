# frozen_string_literal: true

class AddPeriodToDiscourseQuizLeaderboardStats < ActiveRecord::Migration[7.2]
  def up
    return unless table_exists?(:discourse_quiz_leaderboard_stats)

    add_column :discourse_quiz_leaderboard_stats, :period_type, :string, default: "all", null: false, if_not_exists: true
    add_column :discourse_quiz_leaderboard_stats, :period_start, :date, default: "1970-01-01", null: false, if_not_exists: true

    execute <<~SQL
      UPDATE discourse_quiz_leaderboard_stats
      SET period_type = 'all'
      WHERE period_type IS NULL
    SQL

    execute <<~SQL
      UPDATE discourse_quiz_leaderboard_stats
      SET period_start = DATE '1970-01-01'
      WHERE period_start IS NULL
    SQL

    remove_index :discourse_quiz_leaderboard_stats, name: "idx_quiz_leaderboard_stats_user_category", if_exists: true
    remove_index :discourse_quiz_leaderboard_stats, name: "idx_quiz_leaderboard_stats_volume", if_exists: true
    remove_index :discourse_quiz_leaderboard_stats, name: "idx_quiz_leaderboard_stats_accuracy", if_exists: true

    add_index :discourse_quiz_leaderboard_stats,
              %i[user_id category_name period_type period_start],
              unique: true,
              name: "idx_quiz_leaderboard_stats_user_category_period",
              if_not_exists: true

    add_index :discourse_quiz_leaderboard_stats,
              %i[category_name period_type period_start questions_attempted],
              name: "idx_quiz_leaderboard_stats_volume_period",
              if_not_exists: true

    add_index :discourse_quiz_leaderboard_stats,
              %i[category_name period_type period_start accuracy_rate questions_attempted],
              name: "idx_quiz_leaderboard_stats_accuracy_period",
              if_not_exists: true
  end

  def down
    return unless table_exists?(:discourse_quiz_leaderboard_stats)

    remove_index :discourse_quiz_leaderboard_stats, name: "idx_quiz_leaderboard_stats_user_category_period", if_exists: true
    remove_index :discourse_quiz_leaderboard_stats, name: "idx_quiz_leaderboard_stats_volume_period", if_exists: true
    remove_index :discourse_quiz_leaderboard_stats, name: "idx_quiz_leaderboard_stats_accuracy_period", if_exists: true

    add_index :discourse_quiz_leaderboard_stats,
              %i[user_id category_name],
              unique: true,
              name: "idx_quiz_leaderboard_stats_user_category",
              if_not_exists: true

    add_index :discourse_quiz_leaderboard_stats,
              %i[category_name questions_attempted],
              name: "idx_quiz_leaderboard_stats_volume",
              if_not_exists: true

    add_index :discourse_quiz_leaderboard_stats,
              %i[category_name accuracy_rate questions_attempted],
              name: "idx_quiz_leaderboard_stats_accuracy",
              if_not_exists: true

    remove_column :discourse_quiz_leaderboard_stats, :period_type, if_exists: true
    remove_column :discourse_quiz_leaderboard_stats, :period_start, if_exists: true
  end
end
