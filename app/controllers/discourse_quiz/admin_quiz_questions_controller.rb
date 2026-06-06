# frozen_string_literal: true

module DiscourseQuiz
  class AdminQuizQuestionsController < ::Admin::AdminController
    requires_plugin DiscourseQuiz::PLUGIN_NAME

    def index
      questions = QuizQuestion.order(position: :asc, id: :asc)
      questions = questions.by_category(params[:category_name]) if params[:category_name].present?

      render_json_dump(
        questions: serialize_data(questions.to_a, ::AdminQuizQuestionSerializer),
        categories: QuizQuestion.category_names,
      )
    end

    def categories
      render_json_dump(categories: QuizQuestion.category_names)
    end

    def bulk_import
      payload = parse_import_payload
      return if payload.nil?

      imported = 0
      errors = []

      payload.each_with_index do |item, index|
        question = QuizQuestion.new(import_attributes(item))
        if question.save
          imported += 1
        else
          errors << { row: index + 1, messages: question.errors.full_messages }
        end
      end

      render_json_dump(imported: imported, errors: errors, total: payload.length)
    end

    def destroy
      QuizQuestion.find(params[:id]).destroy!
      head :no_content
    end

    private

    def parse_import_payload
      raw = params[:questions_json].to_s.strip
      if raw.blank?
        render_json_dump({ error: I18n.t("discourse_quiz.errors.import_empty") }, status: 422)
        return nil
      end

      data = JSON.parse(raw)
      unless data.is_a?(Array)
        render_json_dump({ error: I18n.t("discourse_quiz.errors.import_not_array") }, status: 422)
        return nil
      end

      data
    rescue JSON::ParserError
      render_json_dump({ error: I18n.t("discourse_quiz.errors.import_invalid_json") }, status: 422)
      nil
    end

    def import_attributes(item)
      attrs = item.is_a?(ActionController::Parameters) ? item : ActionController::Parameters.new(item)
      permitted =
        attrs.permit(:category_name, :question_text, :correct_index, :explanation, :active, :position, options: [])

      permitted[:active] = true if permitted[:active].nil?
      permitted[:position] = permitted[:position].to_i
      permitted
    end
  end
end
