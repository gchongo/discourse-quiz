# frozen_string_literal: true

# name: discourse-quiz
# about: Quiz panel with question bank for Discourse.
# version: 0.15.5
# authors: howhy.day
# url: https://github.com/howhy-day/discourse-quiz

enabled_site_setting :quiz_plugin_enabled

register_asset "stylesheets/common/gamified-quiz.scss"

module ::DiscourseQuiz
  PLUGIN_NAME = "discourse-quiz"
end

require_relative "lib/discourse_quiz/engine"
require_relative "lib/discourse_quiz/seed_questions"
require_relative "lib/discourse_quiz/quiz_status_service"
require_relative "lib/discourse_quiz/quiz_points_service"
require_relative "lib/discourse_quiz/quiz_submission_service"
require_relative "lib/discourse_quiz/question_import_parser"
require_relative "lib/discourse_quiz/question_exporter"
require_relative "lib/discourse_quiz/question_types"
require_relative "lib/discourse_quiz/quiz_question_picker"
require_relative "lib/discourse_quiz/quiz_stats_service"
require_relative "lib/discourse_quiz/quiz_duplicate_detector"
require_relative "lib/discourse_quiz/user_summary_extension"

after_initialize do

  ::UserSummary.prepend(DiscourseQuiz::UserSummaryExtension)

  add_to_serializer(
    :user_summary,
    :quiz_summary_stats,
    include_condition: -> do
      SiteSetting.quiz_plugin_enabled && scope.user&.id == object.user_id &&
        DiscourseQuiz::QuizUserAttempt.table_ready?
    end,
  ) { object.quiz_summary_stats }

  add_admin_route(
    "discourse_quiz.admin.title",
    "discourse-quiz",
    { use_new_show_route: true },
  )

  begin
    DiscourseQuiz::SeedQuestions.seed!
  rescue StandardError => e
    Rails.logger.warn("[discourse-quiz] Failed to seed sample question: #{e.message}")
  end
end
