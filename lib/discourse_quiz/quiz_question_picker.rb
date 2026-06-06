# frozen_string_literal: true

module DiscourseQuiz
  class QuizQuestionPicker
    MODES = %w[normal wrong_only unseen].freeze

    attr_reader :empty_reason

    def initialize(user:, category_names: [], practice_mode: "normal")
      @user = user
      @category_names = normalize_category_names(category_names)
      @practice_mode = MODES.include?(practice_mode.to_s) ? practice_mode.to_s : "normal"
      @empty_reason = nil
    end

    def pick
      scope = filtered_scope
      return nil if scope.none?

      question = scope.order(Arel.sql("RANDOM()")).first
      @empty_reason = empty_reason_for_mode unless question
      question
    end

    def requires_login?
      @practice_mode != "normal"
    end

    private

    def filtered_scope
      scope = base_scope

      case @practice_mode
      when "normal"
        scope
      when "wrong_only"
        wrong_ids = QuizUserAttempt.latest_wrong_question_ids_for(@user.id)
        if wrong_ids.empty?
          @empty_reason = :no_wrong_questions
          return QuizQuestion.none
        end

        filtered = scope.where(id: wrong_ids)
        @empty_reason = :no_wrong_questions if filtered.none?
        filtered
      when "unseen"
        attempted_ids = QuizUserAttempt.attempted_question_ids_for(@user.id)
        filtered = scope.where.not(id: attempted_ids)
        @empty_reason = :no_unseen_questions if filtered.none?
        filtered
      else
        scope
      end
    end

    def base_scope
      scope = QuizQuestion.active
      scope = scope.where(category_name: @category_names) if @category_names.present?
      scope
    end

    def empty_reason_for_mode
      case @practice_mode
      when "wrong_only"
        :no_wrong_questions
      when "unseen"
        :no_unseen_questions
      else
        :no_active_questions
      end
    end

    def normalize_category_names(category_names)
      Array(category_names).map(&:to_s).map(&:strip).reject(&:blank?).uniq
    end
  end
end
