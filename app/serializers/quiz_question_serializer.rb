# frozen_string_literal: true

class QuizQuestionSerializer < ApplicationSerializer
  attributes :id, :category_name, :question_text, :options, :author_username
end
