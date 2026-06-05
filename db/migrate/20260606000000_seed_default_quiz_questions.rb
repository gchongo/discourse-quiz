# frozen_string_literal: true

class SeedDefaultQuizQuestions < ActiveRecord::Migration[7.0]
  SEED_QUESTIONS = [
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
    return unless table_exists?(:discourse_quiz_questions)
    return if select_value("SELECT 1 FROM discourse_quiz_questions LIMIT 1")

    SEED_QUESTIONS.each { |question| insert_question(question) }
  end

  def down
    return unless table_exists?(:discourse_quiz_questions)

    SEED_QUESTIONS.each do |question|
      execute(
        sanitize_sql_array(
          ["DELETE FROM discourse_quiz_questions WHERE question_text = ?", question[:question_text]],
        ),
      )
    end
  end

  private

  def insert_question(question)
    execute(
      sanitize_sql_array(
        [
          <<~SQL.squish,
            INSERT INTO discourse_quiz_questions
              (category_name, question_text, options, correct_index, explanation, active, created_at, updated_at)
            VALUES (?, ?, ?::jsonb, ?, ?, true, NOW(), NOW())
          SQL
          question[:category_name],
          question[:question_text],
          question[:options].to_json,
          question[:correct_index],
          question[:explanation],
        ],
      ),
    )
  end
end
