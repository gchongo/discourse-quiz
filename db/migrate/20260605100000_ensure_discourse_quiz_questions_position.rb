# frozen_string_literal: true

class EnsureDiscourseQuizQuestionsPosition < ActiveRecord::Migration[7.2]
  def up
    return unless table_exists?(:discourse_quiz_questions)
    return if column_exists?(:discourse_quiz_questions, :position)

    add_column :discourse_quiz_questions, :position, :integer, null: false, default: 0
    add_index :discourse_quiz_questions, :position, if_not_exists: true
  end

  def down
    return unless table_exists?(:discourse_quiz_questions)
    return unless column_exists?(:discourse_quiz_questions, :position)

    remove_index :discourse_quiz_questions, :position, if_exists: true
    remove_column :discourse_quiz_questions, :position
  end
end
