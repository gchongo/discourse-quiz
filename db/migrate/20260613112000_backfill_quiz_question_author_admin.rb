# frozen_string_literal: true

class BackfillQuizQuestionAuthorAdmin < ActiveRecord::Migration[7.2]
  def up
    return unless table_exists?(:discourse_quiz_questions)
    return unless column_exists?(:discourse_quiz_questions, :author_username)

    execute <<~SQL
      UPDATE discourse_quiz_questions
      SET author_username = '管理员'
      WHERE 1=1;
    SQL

    if column_exists?(:discourse_quiz_questions, :show_author_name)
      execute <<~SQL
        UPDATE discourse_quiz_questions
        SET show_author_name = TRUE
        WHERE 1=1;
      SQL
    end
  end

  def down
    # no-op
  end
end
