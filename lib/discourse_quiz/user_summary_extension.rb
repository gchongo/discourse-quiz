# frozen_string_literal: true

module DiscourseQuiz::UserSummaryExtension
  extend ActiveSupport::Concern

  def quiz_summary_stats
    return nil unless DiscourseQuiz::QuizUserAttempt.table_ready?

    summary =
      DiscourseQuiz::QuizStatsService.new(@user).summary(
        category_names: quiz_category_allowlist,
      )
    return nil unless summary

    {
      today_correct: summary[:today_correct],
      today_incorrect: summary[:today_incorrect],
      wrong_pending: summary[:wrong_pending],
    }
  end

  private

  def quiz_category_allowlist
    setting = SiteSetting.quiz_categories.to_s.strip
    return [] if setting.blank?

    setting.split(",").map(&:strip).reject(&:blank?)
  end
end
