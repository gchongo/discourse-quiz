# frozen_string_literal: true

class CreateDiscourseQuizQuestions < ActiveRecord::Migration[7.2]
  def up
    create_questions_table
    ensure_position_column
    ensure_indexes
  end

  def down
    drop_table :discourse_quiz_questions, if_exists: true
  end

  private

  def create_questions_table
    return if table_exists?(:discourse_quiz_questions)

    create_table :discourse_quiz_questions do |t|
      t.string :category_name, null: false
      t.text :question_text, null: false
      t.jsonb :options, null: false, default: []
      t.integer :correct_index, null: false
      t.text :explanation
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0

      t.timestamps
    end
  end

  def ensure_position_column
    return unless table_exists?(:discourse_quiz_questions)
    return if column_exists?(:discourse_quiz_questions, :position)

    add_column :discourse_quiz_questions, :position, :integer, null: false, default: 0
  end

  def ensure_indexes
    return unless table_exists?(:discourse_quiz_questions)

    add_index :discourse_quiz_questions, :category_name, if_not_exists: true
    add_index :discourse_quiz_questions, :active, if_not_exists: true
    add_index :discourse_quiz_questions, :position, if_not_exists: true
  end
end
