# frozen_string_literal: true

class CreateQuizTables < ActiveRecord::Migration[7.0]
  def up
    unless table_exists?(:discourse_quiz_questions)
      create_table :discourse_quiz_questions do |t|
        t.string :category_name, null: false
        t.text :question_text, null: false
        t.jsonb :options, null: false, default: []
        t.integer :correct_index, null: false
        t.text :explanation
        t.integer :source_topic_id
        t.boolean :active, null: false, default: true

        t.timestamps
      end

      add_index :discourse_quiz_questions, :active
      add_index :discourse_quiz_questions, :category_name
    end

    unless table_exists?(:discourse_quiz_user_attempts)
      create_table :discourse_quiz_user_attempts do |t|
        t.integer :user_id, null: false
        t.integer :question_id, null: false
        t.boolean :is_correct, null: false
        t.datetime :created_at, null: false
      end

      add_index :discourse_quiz_user_attempts, [:user_id, :question_id]
      add_index :discourse_quiz_user_attempts, :question_id
    end
  end

  def down
    drop_table :discourse_quiz_user_attempts if table_exists?(:discourse_quiz_user_attempts)
    drop_table :discourse_quiz_questions if table_exists?(:discourse_quiz_questions)
  end
end
