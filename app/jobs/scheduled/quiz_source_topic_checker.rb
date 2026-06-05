# frozen_string_literal: true

module Jobs
  class QuizSourceTopicChecker < ::Jobs::Scheduled
    every 7.days

    def execute(args)
      return unless SiteSetting.quiz_plugin_enabled

      DiscourseGamifiedQuiz::QuizQuestion.active.find_each do |question|
        errors = []
        topic_id = question.source_topic_id

        if topic_id.blank?
          # Optional: skip if no source topic is intended
          next
        end

        topic = Topic.with_deleted.find_by(id: topic_id)

        if topic.nil?
          errors << "topic_not_found"
        elsif topic.deleted_at.present?
          errors << "topic_deleted"
        elsif topic.archetype == Archetype.private_message
          errors << "topic_is_private"
        elsif !topic.visible
          errors << "topic_hidden"
        end

        question.update_columns(
          last_checked_at: Time.zone.now,
          validation_errors: errors
        )
      end
    end
  end
end
