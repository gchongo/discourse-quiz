# frozen_string_literal: true

DiscourseQuiz::Engine.routes.draw do
  get "/next" => "quiz#next"
  get "/categories" => "quiz#categories"
  get "/status" => "quiz#status"
  post "/submit" => "quiz#submit"
end

Discourse::Application.routes.draw do
  mount ::DiscourseQuiz::Engine, at: "/quiz"

  scope constraints: AdminConstraint.new do
    get "/admin/plugins/discourse-quiz" => "admin/plugins#index"

    get "/admin/quiz/questions" => "discourse_quiz/admin_quiz_questions#index"
    get "/admin/quiz/categories" => "discourse_quiz/admin_quiz_questions#categories"
    post "/admin/quiz/questions/bulk_import" => "discourse_quiz/admin_quiz_questions#bulk_import"
    delete "/admin/quiz/questions/:id" => "discourse_quiz/admin_quiz_questions#destroy"
  end
end
