# frozen_string_literal: true

require "rails_helper"

describe DiscourseGamifiedQuiz::QuizQuestionPicker do
  let(:user) { Fabricate(:user) }
  let!(:q1) { DiscourseGamifiedQuiz::QuizQuestion.create!(category_name: "C1", question_text: "Q1", options: ["A"], correct_index: 0, active: true) }
  let!(:q2) { DiscourseGamifiedQuiz::QuizQuestion.create!(category_name: "C1", question_text: "Q2", options: ["A"], correct_index: 0, active: true) }

  describe "#pick_next" do
    it "prefers questions the user has not answered correctly" do
      # User answered Q1 correctly
      DiscourseGamifiedQuiz::QuizUserAttempt.create!(user_id: user.id, question_id: q1.id, is_correct: true)
      
      picker = DiscourseGamifiedQuiz::QuizQuestionPicker.new(user)
      # Should pick Q2
      expect(picker.pick_next.id).to eq(q2.id)
    end

    it "picks a random active question if all are answered correctly" do
      DiscourseGamifiedQuiz::QuizUserAttempt.create!(user_id: user.id, question_id: q1.id, is_correct: true)
      DiscourseGamifiedQuiz::QuizUserAttempt.create!(user_id: user.id, question_id: q2.id, is_correct: true)
      
      picker = DiscourseGamifiedQuiz::QuizQuestionPicker.new(user)
      expect([q1.id, q2.id]).to include(picker.pick_next.id)
    end

    it "only picks active questions" do
      q2.update!(active: false)
      picker = DiscourseGamifiedQuiz::QuizQuestionPicker.new(user)
      expect(picker.pick_next.id).to eq(q1.id)
    end
  end
end
