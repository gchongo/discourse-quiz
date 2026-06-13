# frozen_string_literal: true

class BackfillQuizSubmissionStatusPending < ActiveRecord::Migration[7.2]
  def up
    return unless table_exists?(:discourse_quiz_question_submissions)
    return unless column_exists?(:discourse_quiz_question_submissions, :status)

    execute <<~SQL
      UPDATE discourse_quiz_question_submissions
      SET status = 'pending'
      WHERE status IS NULL OR TRIM(status) = '';
    SQL
  end

  def down
    # no-op
  end
end
