# frozen_string_literal: true

module DiscourseQuiz
  class QuizController < ::ApplicationController
    requires_plugin DiscourseQuiz::PLUGIN_NAME

    before_action :ensure_enabled
    before_action :ensure_can_play, only: %i[next submit]

    def next
      picker = QuizQuestionPicker.new(current_user)
      question = picker.pick_next

      unless question
        return(
          render_json_dump(
            { error: I18n.t("gamified_quiz.errors.no_active_questions") },
            status: 404,
          )
        )
      end

      status_service = QuizStatusService.new(current_user, session[:quiz_guest_attempts])
      render_json_dump(
        {
          id: question.id,
          question_text: question.question_text,
          options: question.options,
          category_name: question.category_name,
          source_topic_id: question.source_topic_id,
          status: status_service.get_status,
        },
      )
    end

    def submit
      ensure_not_rate_limited!
      return if performed?

      question = QuizQuestion.active.find_by(id: params[:question_id])
      unless question
        return(
          render_json_dump(
            { error: I18n.t("gamified_quiz.errors.question_not_found") },
            status: 404,
          )
        )
      end

      submission_service =
        QuizSubmissionService.new(current_user, question, params[:answer_index], guardian:)

      result = submission_service.submit
      return render_json_dump(result, status: submission_service.status_code) if submission_service.failed?

      unless current_user
        session[:quiz_guest_attempts] = (session[:quiz_guest_attempts] || 0) + 1
      end

      render_json_dump(result)
    end

    def status
      status_service = QuizStatusService.new(current_user, session[:quiz_guest_attempts])
      render_json_dump(status_service.get_status)
    end

    private

    def ensure_enabled
      raise Discourse::NotFound unless SiteSetting.quiz_plugin_enabled
    end

    def ensure_can_play
      status_service = QuizStatusService.new(current_user, session[:quiz_guest_attempts])
      return if status_service.can_play?

      render_json_dump(
        {
          error: I18n.t("gamified_quiz.errors.paywall_reached"),
          status: status_service.get_status,
        },
        status: 403,
      )
      false
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
