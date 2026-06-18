# frozen_string_literal: true

module DiscourseQuiz
  class QuizSubmissionNotificationService
    def self.notify_approved(submission:, review_note:, points_awarded:)
      user = User.find_by(id: submission.submitter_id)
      return unless user

      SystemMessage.create_from_system_user(
        user,
        :quiz_submission_review_approved,
        category_name: submission.category_name,
        question_excerpt: excerpt(submission.question_text),
        review_note: review_note.presence || I18n.t("discourse_quiz.notifications.no_review_note"),
        points_awarded: points_awarded.to_i,
        daily_cap: SiteSetting.quiz_submission_reward_daily_cap.to_i,
      )
    rescue StandardError => e
      Rails.logger.error("[discourse-quiz] notify_approved failed for submission #{submission.id}: #{e.class}: #{e.message}")
    end

    def self.notify_rejected(submission:, review_note:)
      user = User.find_by(id: submission.submitter_id)
      return unless user

      SystemMessage.create_from_system_user(
        user,
        :quiz_submission_review_rejected,
        category_name: submission.category_name,
        question_excerpt: excerpt(submission.question_text),
        review_note: review_note.presence || I18n.t("discourse_quiz.notifications.no_review_note"),
      )
    rescue StandardError => e
      Rails.logger.error("[discourse-quiz] notify_rejected failed for submission #{submission.id}: #{e.class}: #{e.message}")
    end

    def self.excerpt(text)
      text.to_s.gsub(/\s+/, " ").strip.first(80)
    end
  end
end
