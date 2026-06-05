# frozen_string_literal: true

require "rails_helper"

describe DiscourseQuiz::QuizQuestionPicker do
  let(:user) { Fabricate(:user) }
  let!(:q1) { DiscourseQuiz::QuizQuestion.create!(category_name: "C1", question_text: "Q1", options: ["A"], correct_index: 0, active: true) }
  let!(:q2) { DiscourseQuiz::QuizQuestion.create!(category_name: "C1", question_text: "Q2", options: ["A"], correct_index: 0, active: true) }

  describe "#pick_next" do
    it "prefers questions the user has not answered correctly" do
      # User answered Q1 correctly
      DiscourseQuiz::QuizUserAttempt.create!(user_id: user.id, question_id: q1.id, is_correct: true)
      
      picker = DiscourseQuiz::QuizQuestionPicker.new(user)
      # Should pick Q2
      expect(picker.pick_next.id).to eq(q2.id)
    end

    it "picks a random active question if all are answered correctly" do
      DiscourseQuiz::QuizUserAttempt.create!(user_id: user.id, question_id: q1.id, is_correct: true)
      DiscourseQuiz::QuizUserAttempt.create!(user_id: user.id, question_id: q2.id, is_correct: true)
      
      picker = DiscourseQuiz::QuizQuestionPicker.new(user)
      expect([q1.id, q2.id]).to include(picker.pick_next.id)
    end

    it "only picks active questions" do
      q2.update!(active: false)
      picker = DiscourseQuiz::QuizQuestionPicker.new(user)
      expect(picker.pick_next.id).to eq(q1.id)
    end

    it "filters questions by configured category names" do
      category = Fabricate(:category, name: "Quiz Only")
      other = DiscourseQuiz::QuizQuestion.create!(
        category_name: category.name,
        question_text: "Filtered",
        options: ["A"],
        correct_index: 0,
        active: true,
      )

      SiteSetting.quiz_categories = category.id.to_s
      picker = DiscourseQuiz::QuizQuestionPicker.new(user)
      expect(picker.pick_next.id).to eq(other.id)
    end
  end
end
