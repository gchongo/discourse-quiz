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

      item = {
        "category_name" => hash["category_name"].to_s.strip,
        "question_text" => hash["question_text"].to_s.strip,
        "options" => options,
        "correct_index" => hash["correct_index"].to_i,
        "explanation" => hash["explanation"].to_s.presence,
        "active" => parse_active(hash["active"], default: true),
        "position" => hash["position"].to_i,
      }
      item["id"] = hash["id"].to_i if hash["id"].present?
      item
    end

    def self.normalize_csv_row(row)
      options = normalize_options(row["options"])

      item = {
        "category_name" => row["category_name"].to_s.strip,
        "question_text" => row["question_text"].to_s.strip,
        "options" => options,
        "correct_index" => row["correct_index"].to_s.strip.to_i,
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
  end
end
