# frozen_string_literal: true

module DiscourseQuiz
  class QuizQuestionPicker
    MODES = %w[normal wrong_only unseen].freeze
    RECENT_CORRECT_COOLDOWN = 30.minutes

    attr_reader :empty_reason

    def initialize(user:, category_names: [], practice_mode: "normal", exclude_question_ids: [])
      @user = user
      @category_names = normalize_category_names(category_names)
      @practice_mode = MODES.include?(practice_mode.to_s) ? practice_mode.to_s : "normal"
      @exclude_question_ids = normalize_question_ids(exclude_question_ids)
      @empty_reason = nil
    end

    def pick
      scope = filtered_scope
      return nil if scope.none?

      pool = apply_session_exclusions(scope)
      question = weighted_random_pick(pool)
      @empty_reason = empty_reason_for_mode unless question
      question
    end

    def requires_login?
      @practice_mode != "normal"
    end

    private

    def apply_session_exclusions(scope)
      return scope if @exclude_question_ids.blank?

      remaining = scope.where.not(id: @exclude_question_ids)
      remaining.any? ? remaining : scope
    end

    def weighted_random_pick(scope)
      pool = scope

      if @practice_mode == "normal" && @user
        recent_ids =
          QuizUserAttempt.recent_correct_question_ids_for(
            @user.id,
            within: RECENT_CORRECT_COOLDOWN,
          )
        preferred = scope.where.not(id: recent_ids)
        pool = preferred if preferred.any?
      end

      pool.order(Arel.sql("RANDOM()")).first
    end

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

    def normalize_question_ids(question_ids)
      Array(question_ids).map(&:to_i).reject(&:zero?).uniq
    end
  end
end
