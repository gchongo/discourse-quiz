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
  end
end
