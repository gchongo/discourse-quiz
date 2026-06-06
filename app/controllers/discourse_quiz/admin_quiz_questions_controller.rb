# frozen_string_literal: true

module DiscourseQuiz
  class AdminQuizQuestionsController < ::Admin::AdminController
    requires_plugin DiscourseQuiz::PLUGIN_NAME

    DEFAULT_PER_PAGE = 25
    MAX_PER_PAGE = 100

    def index
      questions_scope = filtered_questions_scope
      total = questions_scope.count
      page = [params[:page].to_i, 1].max
      per_page = per_page_param
      offset = (page - 1) * per_page

      questions = questions_scope.offset(offset).limit(per_page)

      render_json_dump(
        questions: questions.map { |question| question_json(question) },
        categories: QuizQuestion.category_names,
        total: total,
        page: page,
        per_page: per_page,
      )
    rescue ActiveRecord::StatementInvalid => e
      Rails.logger.error("[discourse-quiz] admin#index failed: #{e.message}")
      render_json_dump(
        {
          questions: [],
          categories: [],
          total: 0,
          page: 1,
          per_page: DEFAULT_PER_PAGE,
          error: I18n.t("discourse_quiz.errors.database_unavailable"),
        },
        status: 500,
      )
    end

    def categories
      render_json_dump(categories: QuizQuestion.category_names)
    rescue ActiveRecord::StatementInvalid => e
      Rails.logger.error("[discourse-quiz] admin#categories failed: #{e.message}")
      render_json_dump({ categories: [] })
    end

    def create
      question = QuizQuestion.new(import_attributes(params.require(:question)))

      if question.save
        render_json_dump(question: question_json(question))
      else
        render_json_dump({ errors: question.errors.full_messages }, status: 422)
      end
    end

    def export
      questions = filtered_questions_scope
      format = params[:export_format].to_s.presence || "json"

      case format
      when "csv"
        render_json_dump(export_format: "csv", data: QuestionExporter.to_csv(questions))
      else
        render_json_dump(export_format: "json", data: QuestionExporter.to_json(questions))
      end
    end

    def bulk_import
      payload = parse_import_payload
      return if payload.nil?

      dry_run = ActiveModel::Type::Boolean.new.cast(params[:dry_run])
      upsert = ActiveModel::Type::Boolean.new.cast(params[:upsert])

      result = import_questions(payload, dry_run: dry_run, upsert: upsert)
      render_json_dump(result)
    end

    def rename_category
      from_name = params[:from_name].to_s.strip
      to_name = params[:to_name].to_s.strip

      if from_name.blank? || to_name.blank?
        render_json_dump({ error: I18n.t("discourse_quiz.errors.category_rename_blank") }, status: 422)
        return
      end

      if from_name == to_name
        render_json_dump(updated: 0)
        return
      end

      updated = QuizQuestion.where(category_name: from_name).update_all(category_name: to_name)
      render_json_dump(updated: updated, from_name: from_name, to_name: to_name)
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

    def filtered_questions_scope
      scope = QuizQuestion.ordered_for_admin
      scope = scope.by_category(params[:category_name]) if params[:category_name].present?
      scope = scope.by_question_type(params[:question_type]) if params[:question_type].present?
      scope = scope.search_query(params[:q]) if params[:q].present?
      scope
    end

    def per_page_param
      per_page = params[:per_page].to_i
      per_page = DEFAULT_PER_PAGE if per_page <= 0
      [per_page, MAX_PER_PAGE].min
    end

    def question_json(question)
      json = {
        id: question.id,
        category_name: question.category_name,
        question_text: question.question_text,
        question_type: question.resolved_question_type,
        options: question.options,
        correct_index: question.correct_index,
        correct_indices: question.multiple_choice? ? question.resolved_correct_indices : [],
        explanation: question.explanation,
        active: question.active,
        created_at: question.created_at,
      }
      json[:position] = question.position if QuizQuestion.position_column?
      json
    end

    def import_questions(payload, dry_run:, upsert:)
      imported = 0
      updated = 0
      valid = 0
      errors = []

      payload.each_with_index do |item, index|
        row = index + 1
        question = build_import_question(item, upsert: upsert)

        if question.nil?
          errors << { row: row, messages: [I18n.t("discourse_quiz.errors.question_not_found")] }
          next
        end

        if question.valid?
          valid += 1
          next if dry_run

          if question.persisted?
            question.save!
            updated += 1
          else
            question.save!
            imported += 1
          end
        else
          errors << { row: row, messages: question.errors.full_messages }
        end
      end

      {
        imported: imported,
        updated: updated,
        valid: valid,
        errors: errors,
        total: payload.length,
        dry_run: dry_run,
        upsert: upsert,
      }
    end

    def build_import_question(item, upsert:)
      attrs = import_attributes(item)
      id = item["id"].to_i if item["id"].present?

      if upsert && id.present?
        question = QuizQuestion.find_by(id: id)
        return nil unless question

        question.assign_attributes(attrs)
        question
      else
        QuizQuestion.new(attrs)
      end
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
        attrs.permit(
          :category_name,
          :question_text,
          :question_type,
          :correct_index,
          :explanation,
          :active,
          :position,
          options: [],
          correct_indices: [],
        )

      if permitted[:options].is_a?(String)
        permitted[:options] = permitted[:options].split(/\r?\n/).map(&:strip).reject(&:blank?)
      end

      permitted[:active] = true if permitted[:active].nil?
      permitted[:position] = permitted[:position].to_i if QuizQuestion.position_column?
      permitted
    end
  end
end
