# frozen_string_literal: true

class ::AdminQuizQuestionSerializer < ApplicationSerializer
  attributes :id,
             :category_name,
             :question_text,
             :options,
             :correct_index,
             :explanation,
             :source_topic_id,
             :active,
             :created_at

  attribute :last_checked_at, if: :has_audit_columns?
  attribute :validation_errors, if: :has_audit_columns?

  def last_checked_at
    object[:last_checked_at]
  end

  def validation_errors
    object[:validation_errors] || []
  end

  def has_audit_columns?
    object.has_attribute?(:last_checked_at) && object.has_attribute?(:validation_errors)
  end
end
