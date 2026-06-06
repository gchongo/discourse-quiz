# frozen_string_literal: true

class CreateDiscourseQuizQuestions < ActiveRecord::Migration[7.0]
  def up
    create_questions_table unless table_exists?(:discourse_quiz_questions)
    ensure_position_column
    ensure_indexes
  end

  def down
    drop_table :discourse_quiz_questions if table_exists?(:discourse_quiz_questions)
  end

  private

  def create_questions_table
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

    add_index :discourse_quiz_questions, :category_name unless index_exists?(
      :discourse_quiz_questions,
      :category_name,
    )
    add_index :discourse_quiz_questions, :active unless index_exists?(:discourse_quiz_questions, :active)
    add_index :discourse_quiz_questions, :position unless index_exists?(:discourse_quiz_questions, :position)
  end
end
