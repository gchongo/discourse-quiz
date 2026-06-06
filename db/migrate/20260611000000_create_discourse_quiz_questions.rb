# frozen_string_literal: true

class CreateDiscourseQuizQuestions < ActiveRecord::Migration[7.0]
  SAMPLE_QUESTION = {
    category_name: "示例",
    question_text: "1 + 1 = ?",
    options: %w[1 2 3],
    correct_index: 1,
    explanation: "基础算术：1 + 1 = 2。",
  }.freeze

  def up
    create_questions_table
    ensure_position_column
    seed_sample_question
  end

  def down
    drop_table :discourse_quiz_questions if table_exists?(:discourse_quiz_questions)
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

    add_index :discourse_quiz_questions, :category_name
    add_index :discourse_quiz_questions, :active
    add_index :discourse_quiz_questions, :position
  end

  def ensure_position_column
    return unless table_exists?(:discourse_quiz_questions)
    return if column_exists?(:discourse_quiz_questions, :position)

    add_column :discourse_quiz_questions, :position, :integer, null: false, default: 0
    add_index :discourse_quiz_questions, :position
  end

  def seed_sample_question
    return unless table_exists?(:discourse_quiz_questions)
    return if ActiveRecord::Base.connection.select_value(
      "SELECT COUNT(*) FROM discourse_quiz_questions",
    ).to_i > 0

    now = Time.zone.now
    ActiveRecord::Base.connection.insert_all(
      "discourse_quiz_questions",
      [
        SAMPLE_QUESTION.merge(
          active: true,
          position: 0,
          created_at: now,
          updated_at: now,
        ),
      ],
    )
  end
end
