# frozen_string_literal: true

# name: discourse-quiz
# about: A gamified quiz plugin for Discourse to increase community engagement.
# meta_topic_id: TODO
# version: 1.0.0
# authors: howhy.day
# url: https://github.com/howhy-day/discourse-quiz
# required_version: 3.2.0

enabled_site_setting :quiz_plugin_enabled

# Optional: install discourse-gamification to award quiz points.
register_asset "stylesheets/common/gamified-quiz.scss"

module ::DiscourseQuiz
  PLUGIN_NAME = "discourse-quiz"
end

require_relative "lib/discourse_quiz/engine"

after_initialize do
  add_admin_route(
    "discourse_quiz.admin.title",
    "discourse-quiz",
    { use_new_show_route: true },
  )
end
