# frozen_string_literal: true

DiscourseQuiz::Engine.routes.draw do
  get "/status" => "quiz#status"
  get "/next" => "quiz#next"
  post "/submit" => "quiz#submit"
end

Discourse::Application.routes.draw do
  mount ::DiscourseQuiz::Engine, at: "/quiz"

  scope constraints: AdminConstraint.new do
    get "/admin/plugins/discourse-quiz" => "admin/plugins#index"

    get "/admin/quiz/stats" => "discourse_quiz/admin_quiz_questions#stats"
    get "/admin/quiz/audit" => "discourse_quiz/admin_quiz_questions#audit"
    get "/admin/quiz/questions" => "discourse_quiz/admin_quiz_questions#index"
    post "/admin/quiz/questions" => "discourse_quiz/admin_quiz_questions#create"
    put "/admin/quiz/questions/:id" => "discourse_quiz/admin_quiz_questions#update"
    delete "/admin/quiz/questions/:id" => "discourse_quiz/admin_quiz_questions#destroy"
  end
end
