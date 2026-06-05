# frozen_string_literal: true

DiscourseQuiz::Engine.routes.draw do
  get "/next" => "quiz#next_question"
  post "/submit" => "quiz#submit_answer"
  get "/status" => "quiz#status"
end

Discourse::Application.routes.draw do
  mount ::DiscourseQuiz::Engine, at: "/quiz"
end
