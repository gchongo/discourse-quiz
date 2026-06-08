# frozen_string_literal: true

require "rails_helper"

describe DiscourseQuiz::QuizPointsTierService do
  before do
    SiteSetting.quiz_points_per_question = 10
    SiteSetting.quiz_daily_max_points = 30
    SiteSetting.quiz_tier1_upto_count = 0
  end

  describe ".points_for_award_index" do
    it "uses flat points when tiers are disabled" do
      expect(described_class.points_for_award_index(0)).to eq(10)
      expect(described_class.points_for_award_index(5)).to eq(10)
    end

    it "uses tier boundaries when tiers are enabled" do
      SiteSetting.quiz_tier1_upto_count = 3
      SiteSetting.quiz_tier1_points = 10
      SiteSetting.quiz_tier2_upto_count = 8
      SiteSetting.quiz_tier2_points = 5
      SiteSetting.quiz_tier3_points = 2

      expect(described_class.points_for_award_index(0)).to eq(10)
      expect(described_class.points_for_award_index(2)).to eq(10)
      expect(described_class.points_for_award_index(3)).to eq(5)
      expect(described_class.points_for_award_index(7)).to eq(5)
      expect(described_class.points_for_award_index(8)).to eq(2)
    end
  end

  describe ".awardable_points_for" do
    let(:user) { Fabricate(:user) }

    it "caps the final award by remaining daily points" do
      SiteSetting.quiz_tier1_upto_count = 3
      SiteSetting.quiz_tier1_points = 10
      SiteSetting.quiz_daily_max_points = 28

      question =
        DiscourseQuiz::QuizQuestion.create!(
          category_name: "历史",
          question_text: "Q1",
          options: %w[A B],
          correct_index: 0,
        )

      2.times do |index|
        DiscourseQuiz::QuizUserAttempt.create!(
          user_id: user.id,
          question_id: question.id + index,
          answer_index: 0,
          is_correct: true,
          score_awarded: true,
          points_awarded: 10,
          created_at: Time.zone.now,
        )
      end

      expect(described_class.awardable_points_for(user.id)).to eq(8)
    end
  end
end
