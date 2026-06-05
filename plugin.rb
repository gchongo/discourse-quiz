# frozen_string_literal: true

# name: discourse-quiz
# about: A gamified quiz plugin for Discourse to increase community engagement.
# meta_topic_id: TODO
# version: 0.0.1
# authors: howhy.day
# url: https://github.com/howhy-day/discourse-quiz
# required_version: 2.7.0

enabled_site_setting :quiz_plugin_enabled

register_asset "stylesheets/common/gamified-quiz.scss"

module ::DiscourseQuiz
  PLUGIN_NAME = "discourse-quiz"
end

require_relative "lib/discourse_quiz/engine"
require_relative "lib/discourse_quiz/default_questions_seeder"

after_initialize do
  add_admin_route(
    "gamified_quiz.admin_title",
    "discourse-quiz",
    { use_new_show_route: true },
  )

  begin
    DiscourseQuiz::DefaultQuestionsSeeder.seed!
  rescue StandardError => e
    Rails.logger.warn("[discourse-quiz] Failed to seed default questions: #{e.message}")
  end
end
