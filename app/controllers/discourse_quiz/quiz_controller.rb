# frozen_string_literal: true

module DiscourseQuiz
  class QuizController < ::ApplicationController
    requires_plugin DiscourseQuiz::PLUGIN_NAME

    before_action :ensure_enabled

    def next
      question = QuizQuestion.pick_random(category_name: category_filter)

      unless question
        return(
          render_json_dump(
            { error: I18n.t("discourse_quiz.errors.no_active_questions") },
            status: 404,
          )
        )
      end

      render_serialized(question, QuizQuestionSerializer, root: false)
    end

    def categories
      render_json_dump(categories: QuizQuestion.category_names)
    end

    private

    def ensure_enabled
      raise Discourse::NotFound unless SiteSetting.quiz_plugin_enabled
    end

    def category_filter
      setting = SiteSetting.quiz_categories.to_s.strip
      return nil if setting.blank?

      setting
    end
  end
end
