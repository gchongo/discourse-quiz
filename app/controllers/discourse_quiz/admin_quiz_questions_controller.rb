# frozen_string_literal: true

module DiscourseQuiz
  class AdminQuizQuestionsController < ::Admin::AdminController
    requires_plugin DiscourseQuiz::PLUGIN_NAME

    def index
      unless table_ready?
        return(
          render_json_dump(
            { questions: [], categories: [], error: I18n.t("discourse_quiz.errors.database_unavailable") },
            status: 503,
          )
        )
      end

      questions = QuizQuestion.order(position: :asc, id: :asc)
      questions = questions.by_category(params[:category_name]) if params[:category_name].present?

      render_json_dump(
        questions: questions.map { |question| question_json(question) },
        categories: QuizQuestion.category_names,
      )
    rescue ActiveRecord::StatementInvalid => e
      Rails.logger.error("[discourse-quiz] admin#index failed: #{e.message}")
      render_json_dump(
        { questions: [], categories: [], error: I18n.t("discourse_quiz.errors.database_unavailable") },
        status: 503,
      )
    end

    def categories
      unless table_ready?
        return render_json_dump({ categories: [] })
      end

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

    def destroy
      QuizQuestion.find(params[:id]).destroy!
      head :no_content
    end

    private

    def table_ready?
      ActiveRecord::Base.connection.table_exists?(:discourse_quiz_questions)
    end

    def question_json(question)
      {
        id: question.id,
        category_name: question.category_name,
        question_text: question.question_text,
        options: question.options,
        correct_index: question.correct_index,
        explanation: question.explanation,
        active: question.active,
        position: question.position,
        created_at: question.created_at,
      }
    end

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
