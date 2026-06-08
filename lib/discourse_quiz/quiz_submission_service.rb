# frozen_string_literal: true

module DiscourseQuiz
  class QuizSubmissionService
    attr_reader :status_code, :failed

    def initialize(user, question, answer_index: nil, answer_indices: nil)
      @user = user
      @question = question
      @answer_index = answer_index
      @answer_indices = QuestionTypes.normalize_indices(answer_indices)
      @status_code = 200
      @failed = false
    end

    def submit
      unless valid_answer?
        @status_code = 422
        @failed = true
        return { error: I18n.t("discourse_quiz.errors.invalid_answer_index") }
      end

      is_correct =
        @question.graded_correct?(
          answer_index: single_answer_index,
          answer_indices: @answer_indices,
        )
      points_awarded = 0

      if @user && attempts_table_ready?
        attempt =
          QuizUserAttempt.create!(attempt_attributes.merge(is_correct: is_correct, created_at: Time.zone.now))

        if is_correct
          QuizPointsService.award_points(@user, @question, attempt)
          if attempt.reload.score_awarded
            points_awarded = QuizPointsTierService.attempt_points_value(attempt)
          end
        end
      end

      build_result(is_correct, points_awarded)
    end

    def failed?
      @failed
    end

    private

    def attempt_attributes
      attrs = {
        user_id: @user.id,
        question_id: @question.id,
        answer_index: stored_answer_index,
      }

      if @question.multiple_choice? && attempts_answer_indices_column?
        attrs[:answer_indices] = @answer_indices
      end

      attrs
    end

    def build_result(is_correct, points_awarded)
      result = {
        correct: is_correct,
        explanation: @question.explanation,
        points_awarded: points_awarded,
        question_type: @question.resolved_question_type,
      }

      if @question.multiple_choice?
        result[:correct_indices] = @question.resolved_correct_indices
        result[:correct_options] = @question.correct_option_labels
        result[:submitted_indices] = @answer_indices
      else
        result[:correct_index] = @question.correct_index
        result[:correct_option] = @question.options[@question.correct_index]
      end

      result
    end

    def valid_answer?
      if @question.multiple_choice?
        return false if @answer_indices.blank?

        @answer_indices.all? { |index| index_in_options_range?(index) }
      else
        return false if single_answer_index.nil?

        index_in_options_range?(single_answer_index)
      end
    end

    def single_answer_index
      return nil if @question.multiple_choice?

      @answer_index.nil? ? nil : @answer_index.to_i
    end

    def stored_answer_index
      if @question.multiple_choice?
        @answer_indices.first || 0
      else
        single_answer_index
      end
    end

    def index_in_options_range?(index)
      options = @question.options
      options.is_a?(Array) && index >= 0 && index < options.length
    end

    def attempts_table_ready?
      ActiveRecord::Base.connection.table_exists?(:discourse_quiz_user_attempts)
    end

    def attempts_answer_indices_column?
      ActiveRecord::Base.connection.column_exists?(:discourse_quiz_user_attempts, :answer_indices)
    end
  end
end
