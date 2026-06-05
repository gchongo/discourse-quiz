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

after_initialize do
  add_admin_route(
    "gamified_quiz.admin_title",
    "discourse-quiz",
    { use_new_show_route: true },
  )

  Discourse::Application.routes.append do
    get "/admin/plugins/discourse-quiz" => "admin/plugins#index",
        constraints: AdminConstraint.new

    namespace :admin, constraints: AdminConstraint.new do
      namespace :quiz do
        get "/stats" => "questions#stats"
        resources :questions
      end
    end
  end
end
