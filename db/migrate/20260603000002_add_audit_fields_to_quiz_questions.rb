# frozen_string_literal: true

class AddAuditFieldsToQuizQuestions < ActiveRecord::Migration[7.0]
  def change
    add_column :discourse_quiz_questions, :last_checked_at, :datetime
    add_column :discourse_quiz_questions, :validation_errors, :jsonb, default: []
  end
end
