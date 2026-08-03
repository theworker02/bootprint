# frozen_string_literal: true

module Bootprint
  module Rules
    Finding = Struct.new(
      :rule_id, :title, :category, :severity, :summary, :cause, :impact,
      :evidence, :remediation, :references, :metadata, :source_location,
      :suppressed, :suppression_reason, keyword_init: true
    ) do
      def to_h
        {
          "rule_id" => rule_id,
          "title" => title,
          "category" => category.to_s,
          "severity" => severity.to_s,
          "summary" => summary,
          "cause" => cause,
          "impact" => impact,
          "evidence" => evidence || {},
          "remediation" => remediation || {},
          "references" => references || [],
          "metadata" => metadata || {},
          "source_location" => source_location,
          "suppressed" => !suppressed.nil?,
          "suppression_reason" => suppression_reason
        }.compact
      end

      def blocking?(policy)
        !suppressed && policy.fail_on.include?(severity.to_s)
      end

      # Compatibility readers for 0.1 integrations.
      def path = metadata&.fetch("path", nil) || source_location&.fetch("path", nil)
      def local = evidence&.fetch("source", nil)
      def target = evidence&.fetch("target", nil)
      def message = summary
    end
  end
end
