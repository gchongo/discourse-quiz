# frozen_string_literal: true

class CreateDiscourseQuizTables < ActiveRecord::Migration[7.0]
  DEFAULT_QUESTIONS = [
    {
      category_name: "中国历史",
      question_text: "中国历史上第一个统一的封建王朝是哪个？",
      options: %w[夏朝 商朝 秦朝 汉朝],
      correct_index: 2,
      explanation:
        "公元前221年，秦王嬴政灭六国，建立中国历史上第一个统一的中央集权封建王朝——秦朝。",
    },
    {
      category_name: "中国历史",
      question_text: "丝绸之路最早由哪位皇帝派遣张骞出使西域后逐渐开通？",
      options: %w[汉武帝 唐太宗 秦始皇 宋太祖],
      correct_index: 0,
      explanation: "汉武帝时期派遣张骞出使西域，促进了东西方交流，丝绸之路由此兴盛。",
    },
    {
      category_name: "世界历史",
      question_text: "第一次世界大战结束于哪一年？",
      options: %w[1914 1918 1939 1945],
      correct_index: 1,
      explanation: "第一次世界大战于1914年爆发，1918年11月以同盟国战败告终。",
    },
    {
      category_name: "科学",
      question_text: "地球上含量最多的气体是什么？",
      options: %w[氧气 氮气 二氧化碳 氢气],
      correct_index: 1,
      explanation: "大气中氮气约占78%，是含量最多的气体；氧气约占21%。",
    },
    {
      category_name: "科学",
      question_text: "光在真空中的传播速度约为多少？",
      options: ["30万公里/秒", "3万公里/秒", "3000公里/秒", "300公里/秒"],
      correct_index: 0,
      explanation: "真空中光速约为每秒30万公里，是物理学中的基本常数之一。",
    },
    {
      category_name: "文学",
      question_text: "《红楼梦》的作者一般认为是哪位？",
      options: %w[曹雪芹 罗贯中 施耐庵 吴敬梓],
      correct_index: 0,
      explanation: "《红楼梦》通常认为由清代作家曹雪芹创作，是中国古典小说巅峰之作。",
    },
    {
      category_name: "地理",
      question_text: "世界上面积最大的洲是哪一个？",
      options: %w[亚洲 非洲 北美洲 欧洲],
      correct_index: 0,
      explanation: "亚洲面积约4400万平方公里，是世界上面积最大的洲。",
    },
    {
      category_name: "数学",
      question_text: "一个三角形的内角和是多少度？",
      options: %w[90 180 270 360],
      correct_index: 1,
      explanation: "平面三角形内角和恒等于180度，这是欧几里得几何的基本性质。",
    },
  ].freeze

  def up
    create_questions_table
    create_attempts_table
    ensure_question_audit_columns
    ensure_attempt_score_column
    ensure_guest_token_column
    seed_default_questions
  end

  def down
    drop_table :discourse_quiz_user_attempts if table_exists?(:discourse_quiz_user_attempts)
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
      t.integer :source_topic_id
      t.boolean :active, null: false, default: true
      t.datetime :last_checked_at
      t.jsonb :validation_errors, default: []

      t.timestamps
    end

    add_index :discourse_quiz_questions, :active
    add_index :discourse_quiz_questions, :category_name
  end

  def create_attempts_table
    return if table_exists?(:discourse_quiz_user_attempts)

    create_table :discourse_quiz_user_attempts do |t|
      t.integer :user_id, null: false
      t.integer :question_id, null: false
      t.boolean :is_correct, null: false
      t.boolean :score_awarded, null: false, default: false
      t.string :guest_token
      t.datetime :created_at, null: false
    end

    add_index :discourse_quiz_user_attempts, [:user_id, :question_id]
    add_index :discourse_quiz_user_attempts, :question_id
    add_index :discourse_quiz_user_attempts, [:user_id, :score_awarded]
  end

  def ensure_question_audit_columns
    return unless table_exists?(:discourse_quiz_questions)

    unless column_exists?(:discourse_quiz_questions, :last_checked_at)
      add_column :discourse_quiz_questions, :last_checked_at, :datetime
    end

    unless column_exists?(:discourse_quiz_questions, :validation_errors)
      add_column :discourse_quiz_questions, :validation_errors, :jsonb, default: []
    end
  end

  def ensure_attempt_score_column
    return unless table_exists?(:discourse_quiz_user_attempts)
    return if column_exists?(:discourse_quiz_user_attempts, :score_awarded)

    add_column :discourse_quiz_user_attempts, :score_awarded, :boolean, default: false, null: false
    add_index :discourse_quiz_user_attempts, [:user_id, :score_awarded]
  end

  def ensure_guest_token_column
    return unless table_exists?(:discourse_quiz_user_attempts)
    return if column_exists?(:discourse_quiz_user_attempts, :guest_token)

    add_column :discourse_quiz_user_attempts, :guest_token, :string
  end

  def seed_default_questions
    return unless table_exists?(:discourse_quiz_questions)
    return if ActiveRecord::Base.connection.select_value(
      "SELECT COUNT(*) FROM discourse_quiz_questions",
    ).to_i > 0

    now = Time.zone.now
    rows =
      DEFAULT_QUESTIONS.map do |attrs|
        {
          category_name: attrs[:category_name],
          question_text: attrs[:question_text],
          options: attrs[:options],
          correct_index: attrs[:correct_index],
          explanation: attrs[:explanation],
          active: true,
          validation_errors: [],
          created_at: now,
          updated_at: now,
        }
      end

    ActiveRecord::Base.connection.insert_all("discourse_quiz_questions", rows)
  end
end
