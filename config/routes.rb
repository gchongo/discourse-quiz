# frozen_string_literal: true

DiscourseQuiz::Engine.routes.draw do
  get "/next" => "quiz#next"
  get "/categories" => "quiz#categories"
  get "/status" => "quiz#status"
  get "/summary_stats" => "quiz#summary_stats"
  post "/submit" => "quiz#submit"
  post "/question_submissions" => "quiz_question_submissions#create"
  get "/rewards" => "quiz_rewards#index"
  get "/rewards/claims" => "quiz_rewards#claims"
  post "/rewards/:id/claim" => "quiz_rewards#claim"
  get "/leaderboard" => "quiz_leaderboard#index"
  get "/leaderboard/user_categories" => "quiz_leaderboard#user_categories"
end

Discourse::Application.routes.draw do
  mount ::DiscourseQuiz::Engine, at: "/quiz"

  scope constraints: AdminConstraint.new do
    get "/admin/plugins/discourse-quiz" => "admin/plugins#index"
    get "/admin/plugins/discourse-quiz/discourse-quiz" => "admin/plugins#index"

    get "/admin/quiz/questions" => "discourse_quiz/admin_quiz_questions#index"
    get "/admin/quiz/questions/export" => "discourse_quiz/admin_quiz_questions#export"
    get "/admin/quiz/categories" => "discourse_quiz/admin_quiz_questions#categories"
    post "/admin/quiz/questions" => "discourse_quiz/admin_quiz_questions#create"
    get "/admin/quiz/question_submissions" => "discourse_quiz/admin_quiz_question_submissions#index"
    put "/admin/quiz/question_submissions/:id" => "discourse_quiz/admin_quiz_question_submissions#update"
    put "/admin/quiz/question_submissions/:id/edit" =>
          "discourse_quiz/admin_quiz_question_submissions#edit_submission"
    post "/admin/quiz/questions/bulk_import" => "discourse_quiz/admin_quiz_questions#bulk_import"
    post "/admin/quiz/questions/bulk_disable_duplicates" =>
           "discourse_quiz/admin_quiz_questions#bulk_disable_duplicates"
    put "/admin/quiz/categories/rename" => "discourse_quiz/admin_quiz_questions#rename_category"
    put "/admin/quiz/questions/:id" => "discourse_quiz/admin_quiz_questions#update"
    delete "/admin/quiz/questions/:id" => "discourse_quiz/admin_quiz_questions#destroy"

    get "/admin/quiz/rewards" => "discourse_quiz/admin_quiz_rewards#index"
    post "/admin/quiz/rewards" => "discourse_quiz/admin_quiz_rewards#create"
    put "/admin/quiz/rewards/:id" => "discourse_quiz/admin_quiz_rewards#update"
    delete "/admin/quiz/rewards/:id" => "discourse_quiz/admin_quiz_rewards#destroy"
    put "/admin/quiz/reward_claims/:id" => "discourse_quiz/admin_quiz_rewards#update_claim"
  end
end
