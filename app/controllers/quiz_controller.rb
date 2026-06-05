# frozen_string_literal: true

module DiscourseGamifiedQuiz
  class QuizController < ::ApplicationController
    before_action :ensure_enabled
    before_action :ensure_can_play, only: [:next_question, :submit_answer]

    def next_question
      status_service = QuizStatusService.new(current_user, session[:quiz_guest_attempts])
      picker = QuizQuestionPicker.new(current_user)
      question = picker.pick_next

      if question
        render json: {
          id: question.id,
          question_text: question.question_text,
          options: question.options,
          category_name: question.category_name,
          source_topic_id: question.source_topic_id,
          status: status_service.get_status
        }
      else
        render json: { error: "No active questions available" }, status: 404
      end
    end

    def submit_answer
      question = QuizQuestion.find(params[:question_id])
      
      # Anti-abuse: Rate Limiting & Cooldown
      ensure_not_rate_limited!

      # Increment guest attempts if not logged in
      unless current_user
        session[:quiz_guest_attempts] = (session[:quiz_guest_attempts] || 0) + 1
      end

      submission_service = QuizSubmissionService.new(
        current_user,
        question,
        params[:answer_index]
      )

      render json: submission_service.submit
    end

    def status
      status_service = QuizStatusService.new(current_user, session[:quiz_guest_attempts])
      render json: status_service.get_status
    end

    private

    def ensure_enabled
      unless SiteSetting.quiz_plugin_enabled
        raise Discourse::NotFound
      end
    end

    def ensure_can_play
      status_service = QuizStatusService.new(current_user, session[:quiz_guest_attempts])
      unless status_service.can_play?
        render json: { 
          error: "Paywall reached", 
          status: status_service.get_status 
        }, status: 403
      end
    end

    def ensure_not_rate_limited!
      limit = SiteSetting.quiz_submit_cooldown_seconds
      return if limit <= 0

      if current_user
        RateLimiter.new(current_user, "quiz-submit", 1, limit).performed!
      else
        RateLimiter.new(nil, "quiz-submit-#{request.remote_ip}", 1, limit).performed!
      end
    rescue RateLimiter::LimitExceeded => e
      render_json_error(e.description, status: 429)
    end
  end
end
