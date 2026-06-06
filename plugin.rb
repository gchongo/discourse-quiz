# frozen_string_literal: true

# name: discourse-quiz
# about: Quiz panel with question bank for Discourse.
# version: 0.8.0
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

after_initialize do
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
