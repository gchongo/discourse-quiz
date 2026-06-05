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

    scope "/admin/quiz", constraints: AdminConstraint.new do
      get "/stats" => "discourse_quiz/admin_quiz_questions#stats"
      get "/questions" => "discourse_quiz/admin_quiz_questions#index"
      post "/questions" => "discourse_quiz/admin_quiz_questions#create"
      put "/questions/:id" => "discourse_quiz/admin_quiz_questions#update"
      delete "/questions/:id" => "discourse_quiz/admin_quiz_questions#destroy"
    end
  end
end
