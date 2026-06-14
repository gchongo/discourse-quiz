# frozen_string_literal: true

class AddUniqueAwardIndexToQuizUserAttempts < ActiveRecord::Migration[7.2]
  INDEX_NAME = "idx_quiz_attempts_unique_award_per_question".freeze

  def up
    return unless table_exists?(:discourse_quiz_user_attempts)

    normalize_duplicate_awarded_rows
    add_unique_award_index
  end

  def down
    remove_index :discourse_quiz_user_attempts, name: INDEX_NAME, if_exists: true
  end

  private

  def normalize_duplicate_awarded_rows
    if column_exists?(:discourse_quiz_user_attempts, :points_awarded)
      execute <<~SQL
        WITH ranked AS (
          SELECT id,
                 ROW_NUMBER() OVER (PARTITION BY user_id, question_id ORDER BY id ASC) AS rn
          FROM discourse_quiz_user_attempts
          WHERE score_awarded = TRUE
        )
        UPDATE discourse_quiz_user_attempts a
        SET score_awarded = FALSE,
            points_awarded = 0
        FROM ranked
        WHERE a.id = ranked.id
          AND ranked.rn > 1;
      SQL
    else
      execute <<~SQL
        WITH ranked AS (
          SELECT id,
                 ROW_NUMBER() OVER (PARTITION BY user_id, question_id ORDER BY id ASC) AS rn
          FROM discourse_quiz_user_attempts
          WHERE score_awarded = TRUE
        )
        UPDATE discourse_quiz_user_attempts a
        SET score_awarded = FALSE
        FROM ranked
        WHERE a.id = ranked.id
          AND ranked.rn > 1;
      SQL
    end
  end

  def add_unique_award_index
    return if index_exists?(:discourse_quiz_user_attempts, %i[user_id question_id], name: INDEX_NAME)

    add_index :discourse_quiz_user_attempts,
              %i[user_id question_id],
              unique: true,
              where: "score_awarded = TRUE",
              name: INDEX_NAME
  end
end
