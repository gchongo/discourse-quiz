# frozen_string_literal: true

require "rails_helper"

describe Jobs::QuizSourceTopicChecker do
  let(:job) { Jobs::QuizSourceTopicChecker.new }

  before do
    SiteSetting.quiz_plugin_enabled = true
  end

  it "identifies deleted topics" do
    topic = Fabricate(:topic, deleted_at: Time.zone.now)
    question = DiscourseGamifiedQuiz::QuizQuestion.create!(
      category_name: "General",
      question_text: "Test?",
      options: ["A", "B"],
      correct_index: 0,
      source_topic_id: topic.id,
      active: true
    )

    job.execute({})
    question.reload

    expect(question.validation_errors).to include("topic_deleted")
    expect(question.last_checked_at).to be_present
  end

  it "identifies missing topics" do
    question = DiscourseGamifiedQuiz::QuizQuestion.create!(
      category_name: "General",
      question_text: "Test?",
      options: ["A", "B"],
      correct_index: 0,
      source_topic_id: 99999,
      active: true
    )

    job.execute({})
    question.reload

    expect(question.validation_errors).to include("topic_not_found")
  end

  it "clears errors for valid topics" do
    topic = Fabricate(:topic)
    question = DiscourseGamifiedQuiz::QuizQuestion.create!(
      category_name: "General",
      question_text: "Test?",
      options: ["A", "B"],
      correct_index: 0,
      source_topic_id: topic.id,
      active: true,
      validation_errors: ["some_old_error"]
    )

    job.execute({})
    question.reload

    expect(question.validation_errors).to be_empty
  end
end
