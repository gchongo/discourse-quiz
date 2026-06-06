# frozen_string_literal: true

require "csv"

module DiscourseQuiz
  class QuestionImportParser
    class ImportError < StandardError
      attr_reader :key

      def initialize(key)
        @key = key
        super(key.to_s)
      end
    end

    def self.parse_json(raw)
      raise ImportError, :import_empty if raw.blank?

      data = JSON.parse(raw)
      raise ImportError, :import_not_array unless data.is_a?(Array)

      data.map { |item| normalize_item(item) }
    rescue JSON::ParserError
      raise ImportError, :import_invalid_json
    end

    def self.parse_csv(raw)
      raise ImportError, :import_empty if raw.blank?

      table = CSV.parse(raw.strip, headers: true, liberal_parsing: true)
      raise ImportError, :import_invalid_csv if table.headers.blank?

      table.filter_map do |row|
        next if row["category_name"].to_s.strip.blank? && row["question_text"].to_s.strip.blank?

        normalize_csv_row(row)
      end
    rescue CSV::MalformedCSVError
      raise ImportError, :import_invalid_csv
    end

    def self.normalize_item(item)
      hash = item.is_a?(Hash) ? item.stringify_keys : {}
      options = normalize_options(hash["options"])

      question_type = normalize_question_type(hash["question_type"])

      item = {
        "category_name" => hash["category_name"].to_s.strip,
        "question_text" => hash["question_text"].to_s.strip,
        "question_type" => question_type,
        "options" => options,
        "correct_index" => hash["correct_index"].to_i,
        "correct_indices" => normalize_correct_indices(hash["correct_indices"], hash["correct_index"], question_type),
        "explanation" => hash["explanation"].to_s.presence,
        "active" => parse_active(hash["active"], default: true),
        "position" => hash["position"].to_i,
      }
      item["id"] = hash["id"].to_i if hash["id"].present?
      item
    end

    def self.normalize_csv_row(row)
      options = normalize_options(row["options"])

      question_type = normalize_question_type(row["question_type"])

      item = {
        "category_name" => row["category_name"].to_s.strip,
        "question_text" => row["question_text"].to_s.strip,
        "question_type" => question_type,
        "options" => options,
        "correct_index" => row["correct_index"].to_s.strip.to_i,
        "correct_indices" => normalize_correct_indices(row["correct_indices"], row["correct_index"], question_type),
        "explanation" => row["explanation"].to_s.presence,
        "active" => parse_active(row["active"], default: true),
      }
      item["id"] = row["id"].to_s.strip.to_i if row["id"].present? && row["id"].to_s.strip.present?
      item
    end

    def self.normalize_options(value)
      case value
      when Array
        value.map { |option| option.to_s.strip }.reject(&:blank?)
      when String
        value.split("|").map(&:strip).reject(&:blank?)
      else
        []
      end
    end

    def self.parse_active(value, default:)
      return default if value.nil? || (value.is_a?(String) && value.strip.blank?)

      ActiveModel::Type::Boolean.new.cast(value)
    end

    def self.normalize_question_type(value)
      type = value.to_s.strip.presence || DiscourseQuiz::QuestionTypes::SINGLE_CHOICE
      DiscourseQuiz::QuestionTypes::ALL.include?(type) ? type : DiscourseQuiz::QuestionTypes::SINGLE_CHOICE
    end

    def self.normalize_correct_indices(indices_value, fallback_index, question_type)
      return [] unless question_type == DiscourseQuiz::QuestionTypes::MULTIPLE_CHOICE

      values =
        case indices_value
        when Array
          indices_value
        when String
          if indices_value.include?("|")
            indices_value.split("|")
          else
            indices_value.split(",")
          end
        else
          []
        end

      normalized = DiscourseQuiz::QuestionTypes.normalize_indices(values)
      return normalized if normalized.present?

      fallback = fallback_index.to_i
      fallback.negative? ? [] : [fallback]
    end
  end
end
