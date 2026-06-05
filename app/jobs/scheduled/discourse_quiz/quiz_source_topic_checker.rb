# frozen_string_literal: true

module Jobs
  module DiscourseQuiz
    class QuizSourceTopicChecker < ::Jobs::Scheduled
      every 7.days

      def execute(args)
        return unless SiteSetting.quiz_plugin_enabled

        ::DiscourseQuiz::QuizQuestion.active.find_each do |question|
          errors = []
          topic_id = question.source_topic_id

          next if topic_id.blank?

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
            validation_errors: errors,
          )
        end
      end
    end
  end
end
