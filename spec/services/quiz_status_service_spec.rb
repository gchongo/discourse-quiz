# frozen_string_literal: true

require "rails_helper"

describe DiscourseGamifiedQuiz::QuizStatusService do
  let(:user) { Fabricate(:user) }

  before do
    SiteSetting.quiz_plugin_enabled = true
    SiteSetting.quiz_enable_guest_demo = true
    SiteSetting.quiz_guest_attempt_limit = 2
    SiteSetting.quiz_points_per_question = 10
    SiteSetting.quiz_daily_max_points = 15
  end

  describe "guest status" do
    it "returns normal mode when under limit" do
      service = DiscourseGamifiedQuiz::QuizStatusService.new(nil, 1)
      status = service.get_status
      expect(status[:mode]).to eq(:normal)
      expect(status[:attempts_left]).to eq(1)
    end

    it "returns paywall mode when over limit" do
      service = DiscourseGamifiedQuiz::QuizStatusService.new(nil, 2)
      status = service.get_status
      expect(status[:mode]).to eq(:paywall)
      expect(status[:attempts_left]).to eq(0)
    end
  end

  describe "logged in status" do
    it "returns learning_only when daily max reached" do
      # Mock 2 awarded questions today (2 * 10 = 20 > 15)
      2.times do |i|
        DiscourseGamifiedQuiz::QuizUserAttempt.create!(
          user_id: user.id,
          question_id: i + 100,
          is_correct: true,
          score_awarded: true,
          created_at: Time.zone.now
        )
      end

      service = DiscourseGamifiedQuiz::QuizStatusService.new(user)
      status = service.get_status
      expect(status[:mode]).to eq(:learning_only)
    end
  end
end
