# frozen_string_literal: true

DiscourseQuiz::Engine.routes.draw do
  get "/next" => "quiz#next"
  get "/categories" => "quiz#categories"
  get "/status" => "quiz#status"
  get "/summary_stats" => "quiz#summary_stats"
  post "/submit" => "quiz#submit"
end

Discourse::Application.routes.draw do
  mount ::DiscourseQuiz::Engine, at: "/quiz"

  scope constraints: AdminConstraint.new do
    get "/admin/plugins/discourse-quiz" => "admin/plugins#index"

    get "/admin/quiz/questions" => "discourse_quiz/admin_quiz_questions#index"
    get "/admin/quiz/questions/export" => "discourse_quiz/admin_quiz_questions#export"
    get "/admin/quiz/categories" => "discourse_quiz/admin_quiz_questions#categories"
    post "/admin/quiz/questions" => "discourse_quiz/admin_quiz_questions#create"
    post "/admin/quiz/questions/bulk_import" => "discourse_quiz/admin_quiz_questions#bulk_import"
    post "/admin/quiz/questions/bulk_disable_duplicates" =>
           "discourse_quiz/admin_quiz_questions#bulk_disable_duplicates"
    put "/admin/quiz/categories/rename" => "discourse_quiz/admin_quiz_questions#rename_category"
    put "/admin/quiz/questions/:id" => "discourse_quiz/admin_quiz_questions#update"
    delete "/admin/quiz/questions/:id" => "discourse_quiz/admin_quiz_questions#destroy"
  end
end
