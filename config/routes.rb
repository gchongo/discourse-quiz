# frozen_string_literal: true

DiscourseQuiz::Engine.routes.draw do
  get "/next" => "quiz#next_question"
  post "/submit" => "quiz#submit_answer"
  get "/status" => "quiz#status"
end

Discourse::Application.routes.draw do
  mount ::DiscourseQuiz::Engine, at: "/quiz"

  scope constraints: AdminConstraint.new do
    get "/admin/plugins/discourse-quiz" => "admin/plugins#index"

    get "/admin/quiz/stats" => "admin/quiz/questions#stats"
    get "/admin/quiz/questions" => "admin/quiz/questions#index"
    post "/admin/quiz/questions" => "admin/quiz/questions#create"
    put "/admin/quiz/questions/:id" => "admin/quiz/questions#update"
    delete "/admin/quiz/questions/:id" => "admin/quiz/questions#destroy"
  end
end
