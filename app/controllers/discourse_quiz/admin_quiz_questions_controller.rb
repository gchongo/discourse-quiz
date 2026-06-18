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
      duplicate_index = QuizDuplicateDetector.index_data

      render_json_dump(
        questions:
          questions.map do |question|
            question_json(question, duplicate_map: duplicate_index[:duplicate_map])
          end,
        categories: QuizQuestion.category_names,
        duplicate_summary: duplicate_index[:summary],
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
      assign_admin_author!(question)

      if question.save
        render_json_dump(question: question_json(question), duplicate_warning: duplicate_warning_for(question))
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

    def bulk_disable_duplicates
      result = QuizDuplicateDetector.disable_duplicates!
      render_json_dump(result)
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
      assign_admin_author!(question) if question.respond_to?(:author_user_id) && question.author_user_id.blank?

      if question.save
        render_json_dump(question: question_json(question), duplicate_warning: duplicate_warning_for(question))
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
      scope = apply_duplicate_filter(scope)
      scope
    end

    def apply_duplicate_filter(scope)
      filter = params[:duplicate_filter].to_s
      return scope if filter.blank? || filter == "all"

      duplicate_ids = QuizDuplicateDetector.summary[:question_ids]

      case filter
      when "duplicates_only"
        if duplicate_ids.present?
          scope.where(id: duplicate_ids)
        else
          scope.none
        end
      when "unique_only"
        if duplicate_ids.present?
          scope.where.not(id: duplicate_ids)
        else
          scope
        end
      else
        scope
      end
    end

    def per_page_param
      per_page = params[:per_page].to_i
      per_page = DEFAULT_PER_PAGE if per_page <= 0
      [per_page, MAX_PER_PAGE].min
    end

    def question_json(question, duplicate_map: nil)
      json = {
        id: question.id,
        category_name: question.category_name,
        question_text: question.question_text,
        question_type: question.resolved_question_type,
        options: question.options,
        correct_index: question.correct_index,
        correct_indices: question.multiple_choice? ? question.resolved_correct_indices : [],
        explanation: question.explanation,
        author_user_id: question.respond_to?(:author_user_id) ? question.author_user_id : nil,
        author_username: question.respond_to?(:author_username) ? question.author_username : nil,
        show_author_name: question.respond_to?(:show_author_name) ? question.show_author_name : true,
        active: question.active,
        created_at: question.created_at,
      }
      json[:position] = question.position if QuizQuestion.position_column?

      duplicate_ids = duplicate_ids_for_question(question, duplicate_map: duplicate_map)
      if duplicate_ids.present?
        json[:duplicate_ids] = duplicate_ids
        json[:duplicate_count] = duplicate_ids.size + 1
      end

      json
    end

    def duplicate_ids_for_question(question, duplicate_map: nil)
      map = duplicate_map || QuizDuplicateDetector.duplicate_ids_map
      map[question.id] || []
    end

    def duplicate_warning_for(question)
      duplicate_ids = QuizDuplicateDetector.duplicate_ids_for_text(
        question.question_text,
        exclude_id: question.id,
      )
      return nil if duplicate_ids.blank?

      {
        duplicate_ids: duplicate_ids,
        message: I18n.t(
          "discourse_quiz.admin.duplicate_warning",
          ids: duplicate_ids.join(", "),
        ),
      }
    end

    def import_questions(payload, dry_run:, upsert:)
      imported = 0
      updated = 0
      skipped = 0
      valid = 0
      errors = []
      warnings = []
      seen_import_keys = {}
      key_to_ids = QuizDuplicateDetector.key_to_ids_index

      payload.each_with_index do |item, index|
        row = index + 1
        question = build_import_question(item, upsert: upsert)

        if question.nil?
          errors << { row: row, messages: [I18n.t("discourse_quiz.errors.question_not_found")] }
          next
        end

        if question.valid?
          valid += 1

          skip_reason = duplicate_import_skip_reason(
            question: question,
            seen_import_keys: seen_import_keys,
            key_to_ids: key_to_ids,
          )

          if skip_reason
            skipped += 1
            warnings << {
              row: row,
              skipped: true,
              message: duplicate_import_skip_message(skip_reason),
            }
            next
          end

          mark_import_key_seen!(seen_import_keys, question, row)

          next if dry_run

          if question.persisted?
            question.save!
            updated += 1
          else
            question.save!
            imported += 1
          end

          QuizDuplicateDetector.register_question!(key_to_ids, question)
        else
          errors << { row: row, messages: question.errors.full_messages }
        end
      end

      {
        imported: imported,
        updated: updated,
        skipped: skipped,
        valid: valid,
        errors: errors,
        warnings: warnings,
        total: payload.length,
        dry_run: dry_run,
        upsert: upsert,
      }
    end

    def duplicate_import_skip_reason(question:, seen_import_keys:, key_to_ids:)
      key = QuizDuplicateDetector.normalized_key(question.question_text)
      return nil if key.blank?

      if seen_import_keys[key]
        return { type: :batch, first_row: seen_import_keys[key] }
      end

      if !question.persisted?
        duplicate_ids =
          QuizDuplicateDetector.duplicate_ids_for_text(
            question.question_text,
            key_to_ids: key_to_ids,
          )
        if duplicate_ids.present?
          return { type: :existing, ids: duplicate_ids }
        end
      end

      nil
    end

    def duplicate_import_skip_message(skip_reason)
      case skip_reason[:type]
      when :batch
        I18n.t(
          "discourse_quiz.admin.duplicate_import_skip_batch",
          row: skip_reason[:first_row],
        )
      when :existing
        I18n.t(
          "discourse_quiz.admin.duplicate_import_skip_existing",
          ids: skip_reason[:ids].join(", "),
        )
      end
    end

    def mark_import_key_seen!(seen_import_keys, question, row)
      key = QuizDuplicateDetector.normalized_key(question.question_text)
      return if key.blank?

      seen_import_keys[key] ||= row
    end

    def build_import_question(item, upsert:)
      attrs = import_attributes(item)
      id = item["id"].to_i if item["id"].present?

      if upsert && id.present?
        question = QuizQuestion.find_by(id: id)
        return nil unless question

        question.assign_attributes(attrs)
        assign_admin_author!(question) if question.respond_to?(:author_user_id) && question.author_user_id.blank?
        question
      else
        question = QuizQuestion.new(attrs)
        assign_admin_author!(question)
        question
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
          :show_author_name,
          :position,
          options: [],
          correct_indices: [],
        )

      if permitted[:options].is_a?(String)
        permitted[:options] = permitted[:options].split(/\r?\n/).map(&:strip).reject(&:blank?)
      end

      permitted[:active] = true if permitted[:active].nil?
      if QuizQuestion.column_names.include?("show_author_name")
        permitted[:show_author_name] = true if permitted[:show_author_name].nil?
      else
        permitted.delete(:show_author_name)
      end
      permitted[:position] = permitted[:position].to_i if QuizQuestion.position_column?
      permitted
    end

    def assign_admin_author!(question)
      return unless question.respond_to?(:author_user_id)
      return unless current_user

      question.author_user_id = current_user.id
      question.author_username = "管理员"
    end
  end
end
