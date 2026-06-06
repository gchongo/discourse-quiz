# frozen_string_literal: true

module DiscourseQuiz
  class QuizController < ::ApplicationController
    requires_plugin DiscourseQuiz::PLUGIN_NAME

    before_action :ensure_enabled

    def next
      unless table_ready?
        return(
          render_json_dump(
            { error: I18n.t("discourse_quiz.errors.database_unavailable") },
            status: 503,
          )
        )
      end

      question = QuizQuestion.pick_random(category_names: category_filters)

      unless question
        return(
          render_json_dump(
            { error: I18n.t("discourse_quiz.errors.no_active_questions") },
            status: 404,
          )
        )
      end

      render_json_dump(
        {
          id: question.id,
          category_name: question.category_name,
          question_text: question.question_text,
          options: question.options,
        },
      )
    rescue ActiveRecord::StatementInvalid => e
      Rails.logger.error("[discourse-quiz] quiz#next failed: #{e.message}")
      render_json_dump(
        { error: I18n.t("discourse_quiz.errors.database_unavailable") },
        status: 503,
      )
    end

    def categories
      render_json_dump(categories: QuizQuestion.category_names)
    end

    def submit
      unless table_ready?
        return(
          render_json_dump(
            { error: I18n.t("discourse_quiz.errors.database_unavailable") },
            status: 503,
          )
        )
      end

      question = QuizQuestion.active.find_by(id: params[:question_id].to_i)
      unless question
        return(
          render_json_dump(
            { error: I18n.t("discourse_quiz.errors.question_not_found") },
            status: 404,
          )
        )
      end

      answer_index = params[:answer_index].to_i
      unless valid_answer_index?(question, answer_index)
        return(
          render_json_dump(
            { error: I18n.t("discourse_quiz.errors.invalid_answer_index") },
            status: 422,
          )
        )
      end

      correct = answer_index == question.correct_index

      render_json_dump(
        {
          correct: correct,
          explanation: question.explanation,
          correct_index: question.correct_index,
          correct_option: question.options[question.correct_index],
        },
      )
    rescue ActiveRecord::StatementInvalid => e
      Rails.logger.error("[discourse-quiz] quiz#submit failed: #{e.message}")
      render_json_dump(
        { error: I18n.t("discourse_quiz.errors.database_unavailable") },
        status: 503,
      )
    end

    private

    def ensure_enabled
      raise Discourse::NotFound unless SiteSetting.quiz_plugin_enabled
    end

    def table_ready?
      ActiveRecord::Base.connection.table_exists?(:discourse_quiz_questions)
    end

    def category_filters
      setting = SiteSetting.quiz_categories.to_s.strip
      return [] if setting.blank?

      setting.split(",").map(&:strip).reject(&:blank?)
    end

    def valid_answer_index?(question, answer_index)
      question.options.is_a?(Array) && answer_index >= 0 && answer_index < question.options.length
    end
  end
end
