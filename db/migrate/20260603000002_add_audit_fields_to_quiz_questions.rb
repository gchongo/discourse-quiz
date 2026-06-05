# frozen_string_literal: true

class AddAuditFieldsToQuizQuestions < ActiveRecord::Migration[7.0]
  def up
    return unless table_exists?(:discourse_quiz_questions)

    unless column_exists?(:discourse_quiz_questions, :last_checked_at)
      add_column :discourse_quiz_questions, :last_checked_at, :datetime
    end

    unless column_exists?(:discourse_quiz_questions, :validation_errors)
      add_column :discourse_quiz_questions, :validation_errors, :jsonb, default: []
    end
  end

  def down
    return unless table_exists?(:discourse_quiz_questions)

    remove_column :discourse_quiz_questions, :validation_errors if column_exists?(
      :discourse_quiz_questions,
      :validation_errors,
    )
    remove_column :discourse_quiz_questions, :last_checked_at if column_exists?(
      :discourse_quiz_questions,
      :last_checked_at,
    )
  end
end
