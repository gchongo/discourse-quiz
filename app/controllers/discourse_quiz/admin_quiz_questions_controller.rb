# frozen_string_literal: true

module DiscourseQuiz
  class AdminQuizQuestionsController < ::Admin::AdminController
    requires_plugin DiscourseQuiz::PLUGIN_NAME

    def index
      questions = QuizQuestion.ordered_for_admin
      questions = questions.by_category(params[:category_name]) if params[:category_name].present?

      render_json_dump(
        questions: questions.map { |question| question_json(question) },
        categories: QuizQuestion.category_names,
      )
    rescue ActiveRecord::StatementInvalid => e
      Rails.logger.error("[discourse-quiz] admin#index failed: #{e.message}")
      render_json_dump(
        { questions: [], categories: [], error: I18n.t("discourse_quiz.errors.database_unavailable") },
        status: 500,
      )
    end

    def categories
      render_json_dump(categories: QuizQuestion.category_names)
    rescue ActiveRecord::StatementInvalid => e
      Rails.logger.error("[discourse-quiz] admin#categories failed: #{e.message}")
      render_json_dump({ categories: [] })
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

    def update
      question = QuizQuestion.find_by(id: params[:id])

      unless question
        render_json_dump({ error: I18n.t("discourse_quiz.errors.question_not_found") }, status: 404)
        return
      end

      question.assign_attributes(import_attributes(params.require(:question)))

      if question.save
        render_json_dump(question: question_json(question))
      else
        render_json_dump({ errors: question.errors.full_messages }, status: 422)
      end
    end

    def destroy
      QuizQuestion.find(params[:id]).destroy!
      head :no_content
    end

    private

    def question_json(question)
      json = {
        id: question.id,
        category_name: question.category_name,
        question_text: question.question_text,
        options: question.options,
        correct_index: question.correct_index,
        explanation: question.explanation,
        active: question.active,
        created_at: question.created_at,
      }
      json[:position] = question.position if QuizQuestion.position_column?
      json
    end

    def parse_import_payload
      raw = params[:questions_json].to_s.strip
      format = params[:import_format].to_s.presence || "json"

      case format
      when "csv"
        QuestionImportParser.parse_csv(raw)
      else
        QuestionImportParser.parse_json(raw)
      end
    rescue QuestionImportParser::ImportError => e
      render_json_dump({ error: I18n.t("discourse_quiz.errors.#{e.key}") }, status: 422)
      nil
    end

    def import_attributes(item)
      attrs = item.is_a?(ActionController::Parameters) ? item : ActionController::Parameters.new(item)
      permitted =
        attrs.permit(:category_name, :question_text, :correct_index, :explanation, :active, :position, options: [])

      if permitted[:options].is_a?(String)
        permitted[:options] = permitted[:options].split(/\r?\n/).map(&:strip).reject(&:blank?)
      end

      permitted[:active] = true if permitted[:active].nil?
      permitted[:position] = permitted[:position].to_i if QuizQuestion.position_column?
      permitted
    end
  end
end
