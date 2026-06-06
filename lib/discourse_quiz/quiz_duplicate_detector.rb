# frozen_string_literal: true

module DiscourseQuiz
  class QuizDuplicateDetector
    def self.normalize(text)
      text.to_s.strip.gsub(/\s+/, " ")
    end

    def self.normalized_key(text)
      normalize(text).downcase
    end

    def self.key_to_ids_index
      key_to_ids = Hash.new { |h, k| h[k] = [] }

      QuizQuestion.pluck(:id, :question_text).each do |id, question_text|
        key = normalized_key(question_text)
        next if key.blank?

        key_to_ids[key] << id
      end

      key_to_ids
    end

    def self.index_data(key_to_ids = nil)
      key_to_ids ||= key_to_ids_index
      duplicate_groups = key_to_ids.select { |_key, ids| ids.size > 1 }
      duplicate_map = {}

      duplicate_groups.each_value do |ids|
        ids.each { |id| duplicate_map[id] = ids - [id] }
      end

      question_ids = duplicate_groups.values.flatten.uniq

      {
        key_to_ids: key_to_ids,
        duplicate_groups: duplicate_groups,
        duplicate_map: duplicate_map,
        summary: {
          duplicate_group_count: duplicate_groups.size,
          duplicate_question_count: question_ids.size,
          question_ids: question_ids,
        },
      }
    end

    def self.duplicate_groups
      index_data[:duplicate_groups]
    end

    def self.duplicate_ids_map
      index_data[:duplicate_map]
    end

    def self.summary
      index_data[:summary]
    end

    def self.duplicate_ids_for_text(question_text, exclude_id: nil, key_to_ids: nil)
      key = normalized_key(question_text)
      return [] if key.blank?

      ids =
        if key_to_ids
          (key_to_ids[key] || []).dup
        else
          key_to_ids_index[key] || []
        end

      if exclude_id.present?
        ids.reject! { |id| id == exclude_id.to_i }
      end

      ids
    end

    def self.register_question!(key_to_ids, question)
      key = normalized_key(question.question_text)
      return if key.blank?

      key_to_ids[key] << question.id unless key_to_ids[key].include?(question.id)
    end
  end
end
