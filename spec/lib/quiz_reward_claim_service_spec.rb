# frozen_string_literal: true

RSpec.describe DiscourseQuiz::QuizRewardClaimService do
  fab!(:user)
  fab!(:reward) do
    DiscourseQuiz::QuizReward.create!(
      name: "Test card",
      category: "card",
      points_threshold: 10,
      stock: 2,
      active: true,
    )
  end

  before do
    SiteSetting.quiz_plugin_enabled = true
    SiteSetting.quiz_rewards_enabled = true
    SiteSetting.quiz_rewards_use_gamification_score = false
  end

  def award_quiz_points!(points)
    question = DiscourseQuiz::QuizQuestion.create!(
      category_name: "测试",
      question_text: "Q#{SecureRandom.hex(4)}",
      question_type: "single_choice",
      options: %w[A B],
      correct_index: 0,
      active: true,
    )

    attempt =
      DiscourseQuiz::QuizUserAttempt.create!(
        user_id: user.id,
        question_id: question.id,
        is_correct: true,
        score_awarded: true,
        points_awarded: points,
      )
    attempt
  end

  describe ".claim!" do
    it "creates a pending claim without deducting quiz points" do
      award_quiz_points!(15)

      claim = described_class.claim!(user, reward)

      expect(claim.status).to eq("pending")
      expect(DiscourseQuiz::QuizRewardPointsService.cumulative_points_for(user)).to eq(15)
      expect(reward.reload.stock).to eq(1)
    end

    it "rejects claims below the threshold" do
      award_quiz_points!(5)

      expect { described_class.claim!(user, reward) }.to raise_error(
        DiscourseQuiz::QuizRewardClaimService::Error,
      ) do |error|
        expect(error.error_code).to eq(:insufficient_points)
      end
    end

    it "rejects duplicate claims" do
      award_quiz_points!(15)
      described_class.claim!(user, reward)

      expect { described_class.claim!(user, reward) }.to raise_error(
        DiscourseQuiz::QuizRewardClaimService::Error,
      ) do |error|
        expect(error.error_code).to eq(:already_claimed)
      end
    end
  end
end
