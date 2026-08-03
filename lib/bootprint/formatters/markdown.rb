# frozen_string_literal: true

module Bootprint
  module Formatters
    class Markdown
      def initialize(report) = @report = report

      def render
        output = +"# Bootprint Diagnosis\n\n"
        output << "| Source | Target | Blocking |\n|---|---|---|\n"
        output << "| #{@report.source.name} | #{@report.target.name} | #{@report.blocking? ? 'Yes' : 'No'} |\n\n"
        @report.findings.each do |finding|
          output << "## #{finding.severity.to_s.upcase}: #{finding.title}\n\n"
          output << "#{finding.summary}\n\n"
          output << "**Impact:** #{finding.impact}\n\n" if finding.impact
          if finding.remediation&.fetch("summary", nil)
            output << "**Recommended fix:** #{finding.remediation['summary']}\n\n"
            Array(finding.remediation["commands"]).each { |command| output << "```console\n#{command}\n```\n\n" }
          end
        end
        output << "## Summary\n\n"
        output << @report.counts.map { |severity, count| "- #{severity}: #{count}" }.join("\n") << "\n"
        output
      end
    end
  end
end
