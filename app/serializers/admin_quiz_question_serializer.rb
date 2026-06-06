# frozen_string_literal: true

class AdminQuizQuestionSerializer < ApplicationSerializer
  attributes :id,
             :category_name,
             :question_text,
             :options,
             :correct_index,
             :explanation,
             :active,
             :position,
             :created_at
end
