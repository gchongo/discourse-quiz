# frozen_string_literal: true

class AddQuizQuestionTypes < ActiveRecord::Migration[7.2]
  def up
    return unless table_exists?(:discourse_quiz_questions)

    unless column_exists?(:discourse_quiz_questions, :question_type)
      add_column :discourse_quiz_questions,
                  :question_type,
                  :string,
                  null: false,
                  default: "single_choice"
    end

    unless column_exists?(:discourse_quiz_questions, :correct_indices)
      add_column :discourse_quiz_questions,
                  :correct_indices,
                  :jsonb,
                  null: false,
                  default: []
    end

    return unless table_exists?(:discourse_quiz_user_attempts)

    return if column_exists?(:discourse_quiz_user_attempts, :answer_indices)

    add_column :discourse_quiz_user_attempts, :answer_indices, :jsonb
  end

  def down
    return unless table_exists?(:discourse_quiz_questions)

    remove_column :discourse_quiz_questions, :correct_indices if column_exists?(
      :discourse_quiz_questions,
      :correct_indices,
    )
    remove_column :discourse_quiz_questions, :question_type if column_exists?(
      :discourse_quiz_questions,
      :question_type,
    )

    return unless table_exists?(:discourse_quiz_user_attempts)

    remove_column :discourse_quiz_user_attempts, :answer_indices if column_exists?(
      :discourse_quiz_user_attempts,
      :answer_indices,
    )
  end
end
