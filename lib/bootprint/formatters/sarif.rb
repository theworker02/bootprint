# frozen_string_literal: true

require "json"

module Bootprint
  module Formatters
    class Sarif
      LEVELS = { critical: "error", error: "error", warning: "warning", info: "note" }.freeze

      def initialize(report) = @report = report

      def render
        rules = @report.findings.map(&:rule_id).uniq.map do |id|
          finding = @report.findings.find { |candidate| candidate.rule_id == id }
          {
            "id" => id,
            "name" => id.tr("-", "_"),
            "shortDescription" => { "text" => finding.title },
            "help" => { "text" => finding.remediation&.fetch("summary", "Review this environment difference.") }
          }
        end
        results = @report.findings.map do |finding|
          result = {
            "ruleId" => finding.rule_id,
            "level" => finding.suppressed ? "none" : LEVELS.fetch(finding.severity),
            "message" => { "text" => [finding.summary, finding.impact, finding.remediation&.fetch("summary", nil)].compact.join(" ") },
            "properties" => { "category" => finding.category.to_s, "evidence" => finding.evidence, "suppressed" => finding.suppressed }
          }
          location = physical_location(finding.source_location)
          result["locations"] = [{ "physicalLocation" => location }] if location
          result["suppressions"] = [{ "kind" => "external", "justification" => finding.suppression_reason }] if finding.suppressed
          result
        end
        driver = { "name" => "Bootprint", "version" => VERSION, "rules" => rules }
        run = { "tool" => { "driver" => driver }, "results" => results }
        output = ::JSON.pretty_generate(
          "version" => "2.1.0",
          "$schema" => "https://json.schemastore.org/sarif-2.1.0.json",
          "runs" => [run]
        )
        "#{output}\n"
      end

      private

      def physical_location(location)
        return unless location && File.file?(location["path"])

        region = location["line"] ? { "startLine" => location["line"] } : nil
        { "artifactLocation" => { "uri" => location["path"] }, "region" => region }.compact
      end
    end
  end
end
