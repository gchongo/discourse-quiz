# frozen_string_literal: true

require "rails_helper"

describe UserSummarySerializer do
  fab!(:user)
  fab!(:other_user) { Fabricate(:user) }

  let(:guardian) { Guardian.new(user) }
  let(:other_guardian) { Guardian.new(other_user) }
  let(:user_summary) { UserSummary.new(user, guardian) }
  let(:serializer) { described_class.new(user_summary, scope: guardian, root: false) }

  before { SiteSetting.quiz_plugin_enabled = true }

  describe "quiz_summary_stats" do
    let!(:question) do
      DiscourseQuiz::QuizQuestion.create!(
        category_name: "历史",
        question_text: "Q1",
        options: %w[A B],
        correct_index: 0,
      )
    end

    it "is included when viewing your own summary" do
      DiscourseQuiz::QuizUserAttempt.create!(
        user_id: user.id,
        question_id: question.id,
        answer_index: 1,
        is_correct: false,
        created_at: Time.zone.now,
      )

      stats = serializer.as_json[:quiz_summary_stats]

      expect(stats[:today_correct]).to eq(0)
      expect(stats[:today_incorrect]).to eq(1)
      expect(stats[:wrong_pending]).to eq(1)
    end

    it "is omitted when viewing another user's summary" do
      other_summary = UserSummary.new(user, other_guardian)
      other_serializer =
        described_class.new(other_summary, scope: other_guardian, root: false)

      expect(other_serializer.as_json).not_to have_key(:quiz_summary_stats)
    end

    it "is omitted when the plugin is disabled" do
      SiteSetting.quiz_plugin_enabled = false

      expect(serializer.as_json).not_to have_key(:quiz_summary_stats)
    end
  end
end
