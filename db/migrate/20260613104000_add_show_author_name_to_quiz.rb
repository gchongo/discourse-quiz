# frozen_string_literal: true

class AddShowAuthorNameToQuiz < ActiveRecord::Migration[7.2]
  def up
    add_show_author_name_to_questions
    add_show_author_name_to_submissions
  end

  def down
    remove_column :discourse_quiz_questions, :show_author_name, if_exists: true
    remove_column :discourse_quiz_question_submissions, :show_author_name, if_exists: true
  end

  private

  def add_show_author_name_to_questions
    return unless table_exists?(:discourse_quiz_questions)

    add_column :discourse_quiz_questions, :show_author_name, :boolean, default: true, null: false, if_not_exists: true
  end

  def add_show_author_name_to_submissions
    return unless table_exists?(:discourse_quiz_question_submissions)

    add_column :discourse_quiz_question_submissions, :show_author_name, :boolean, default: true, null: false, if_not_exists: true
  end
end
