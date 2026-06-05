# frozen_string_literal: true

# name: discourse-gamified-quiz
# about: A gamified quiz plugin for Discourse to increase community engagement.
# meta_topic_id: TODO
# version: 0.0.1
# authors: howhy.day
# url: https://github.com/howhy-day/discourse-gamified-quiz
# required_version: 2.7.0

enabled_site_setting :quiz_plugin_enabled

register_asset "stylesheets/common/gamified-quiz.scss"

after_initialize do
  # Phase 1: Site Settings & i18n Skeleton.
  # Business logic will be added in subsequent phases.

  module ::DiscourseGamifiedQuiz
    PLUGIN_NAME = "discourse-gamified-quiz"

    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscourseGamifiedQuiz
    end
  end

  DiscourseGamifiedQuiz::Engine.routes.draw do
    get "/next" => "quiz#next_question"
    post "/submit" => "quiz#submit_answer"
    get "/status" => "quiz#status"
  end

  # Admin Routes
  add_admin_route "js.gamified_quiz.admin_title", "gamifiedQuiz"

  Discourse::Application.routes.append do
    mount ::DiscourseGamifiedQuiz::Engine, at: "/quiz"
    get "/admin/plugins/gamified-quiz" => "admin/plugins#index", constraints: AdminConstraint.new
    namespace :admin, constraints: AdminConstraint.new do
      namespace :gamified_quiz do
        resources :questions
        get "/stats" => "questions#stats"
      end
    end
  end

  # TODO: Register custom fields for topics or users if needed for scoring.
  # TODO: Add API routes for quiz management and participation.
end
