# frozen_string_literal: true

class AdminQuizQuestionSerializer < ApplicationSerializer
  attributes :id,
             :category_name,
             :question_text,
             :options,
             :correct_index,
             :explanation,
             :source_topic_id,
             :active,
             :last_checked_at,
             :validation_errors,
             :created_at
end
