# frozen_string_literal: true

require "rails_helper"

describe DiscourseQuiz::QuizDuplicateDetector do
  let!(:first_q) do
    DiscourseQuiz::QuizQuestion.create!(
      category_name: "历史",
      question_text: "秦朝是哪年统一的？",
      options: %w[A B],
      correct_index: 0,
    )
  end

  let!(:duplicate_q) do
    DiscourseQuiz::QuizQuestion.create!(
      category_name: "地理",
      question_text: "  秦朝是哪年统一的？ ",
      options: %w[A B C],
      correct_index: 1,
    )
  end

  let!(:unique_q) do
    DiscourseQuiz::QuizQuestion.create!(
      category_name: "历史",
      question_text: "汉朝是哪年建立的？",
      options: %w[A B],
      correct_index: 0,
    )
  end

  it "finds duplicate groups by normalized question text" do
    groups = described_class.duplicate_groups

    expect(groups.size).to eq(1)
    expect(groups.values.first).to contain_exactly(first_q.id, duplicate_q.id)
  end

  it "maps duplicate ids per question" do
    map = described_class.duplicate_ids_map

    expect(map[first_q.id]).to contain_exactly(duplicate_q.id)
    expect(map[duplicate_q.id]).to contain_exactly(first_q.id)
    expect(map[unique_q.id]).to be_nil
  end

  it "summarizes duplicate counts" do
    summary = described_class.summary

    expect(summary[:duplicate_group_count]).to eq(1)
    expect(summary[:duplicate_question_count]).to eq(2)
    expect(summary[:question_ids]).to contain_exactly(first_q.id, duplicate_q.id)
  end

  it "finds duplicates for text excluding the current question" do
    ids =
      described_class.duplicate_ids_for_text(
        "秦朝是哪年统一的？",
        exclude_id: first_q.id,
      )

    expect(ids).to contain_exactly(duplicate_q.id)
  end

  it "builds map and summary from a single index pass" do
    key_to_ids = described_class.key_to_ids_index
    data = described_class.index_data(key_to_ids)

    expect(data[:duplicate_map][first_q.id]).to contain_exactly(duplicate_q.id)
    expect(data[:summary][:duplicate_group_count]).to eq(1)
    expect(data[:summary][:duplicate_question_count]).to eq(2)
  end

  it "reuses key_to_ids when checking duplicate text during import" do
    key_to_ids = described_class.key_to_ids_index

    ids =
      described_class.duplicate_ids_for_text(
        "新导入题干",
        key_to_ids: key_to_ids,
      )
    expect(ids).to eq([])

    new_q =
      DiscourseQuiz::QuizQuestion.create!(
        category_name: "历史",
        question_text: "新导入题干",
        options: %w[A B],
        correct_index: 0,
      )
    described_class.register_question!(key_to_ids, new_q)

    ids =
      described_class.duplicate_ids_for_text(
        "新导入题干",
        exclude_id: new_q.id,
        key_to_ids: key_to_ids,
      )
    expect(ids).to eq([])

    another =
      described_class.duplicate_ids_for_text(
        "新导入题干",
        key_to_ids: key_to_ids,
      )
    expect(another).to contain_exactly(new_q.id)
  end

  it "disables duplicate questions while keeping the lowest id in each group" do
    result = described_class.disable_duplicates!

    expect(result[:disabled]).to eq(1)
    expect(result[:kept_count]).to eq(1)
    expect(result[:kept_ids]).to contain_exactly(first_q.id)
    expect(first_q.reload.active).to eq(true)
    expect(duplicate_q.reload.active).to eq(false)
    expect(unique_q.reload.active).to eq(true)
  end
end
