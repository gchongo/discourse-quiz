# frozen_string_literal: true

class AddAuthorAndSubmissionsToQuiz < ActiveRecord::Migration[7.2]
  def up
    add_author_columns_to_questions
    create_submissions_table
  end

  def down
    drop_table :discourse_quiz_question_submissions, if_exists: true
    remove_column :discourse_quiz_questions, :author_user_id, if_exists: true
    remove_column :discourse_quiz_questions, :author_username, if_exists: true
  end

  private

  def add_author_columns_to_questions
    return unless table_exists?(:discourse_quiz_questions)

    add_column :discourse_quiz_questions, :author_user_id, :integer, if_not_exists: true
    add_column :discourse_quiz_questions, :author_username, :string, if_not_exists: true
    add_index :discourse_quiz_questions, :author_user_id, if_not_exists: true
  end

  def create_submissions_table
    return if table_exists?(:discourse_quiz_question_submissions)

    create_table :discourse_quiz_question_submissions do |t|
      t.integer :submitter_id, null: false
      t.string :submitter_username, null: false
      t.string :category_name, null: false
      t.text :question_text, null: false
      t.string :question_type, null: false, default: "single_choice"
      t.jsonb :options, null: false, default: []
      t.integer :correct_index, null: false, default: 0
      t.jsonb :correct_indices, null: false, default: []
      t.text :explanation
      t.string :status, null: false, default: "pending"
      t.integer :reviewer_id
      t.datetime :reviewed_at
      t.text :review_note
      t.bigint :approved_question_id
      t.timestamps
    end

    add_index :discourse_quiz_question_submissions, :submitter_id
    add_index :discourse_quiz_question_submissions, :status
    add_index :discourse_quiz_question_submissions, :approved_question_id
  end
end
