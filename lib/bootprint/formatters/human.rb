# frozen_string_literal: true

module Bootprint
  module Formatters
    class Human
      COLORS = { critical: 31, error: 31, warning: 33, info: 36 }.freeze

      def initialize(report, color: false)
        @report = report
        @color = color && !ENV.key?("NO_COLOR")
      end

      def render
        output = "Bootprint Diagnosis\nSource: #{@report.source.name}\nTarget: #{@report.target.name}\n"
        active = @report.findings
        if active.empty?
          output << "\nNo findings at the selected severity.\n"
        else
          active.each { |finding| output << render_finding(finding) }
        end
        output << "\nSummary:\n"
        @report.counts.each { |severity, count| output << format("  %-8s %d\n", severity, count) if count.positive? }
        output << "  blocking #{@report.blocking? ? 'yes' : 'no'}\n"
        output
      end

      private

      def render_finding(finding)
        label = finding.suppressed ? "SUPPRESSED" : finding.severity.to_s.upcase
        heading = format("%-10s %s", colorize(label, finding.severity), finding.title)
        body = "\n\n#{heading}\n          #{finding.summary}\n"
        body << "\n          Why: #{finding.cause}\n" if finding.cause
        body << "          Impact: #{finding.impact}\n" if finding.impact
        evidence = finding.evidence || {}
        body << "          Evidence: #{compact(evidence)}\n" unless evidence.empty?
        remediation = finding.remediation || {}
        if remediation["summary"]
          body << "\n          Recommended fix:\n          #{remediation['summary']}\n"
          Array(remediation["commands"]).each { |command| body << "          $ #{command}\n" }
        end
        body << "          Suppression: #{finding.suppression_reason}\n" if finding.suppressed
        body
      end

      def compact(value)
        value.inspect.gsub(/\s+/, " ")
      end

      def colorize(text, severity)
        @color ? "\e[#{COLORS.fetch(severity)}m#{text}\e[0m" : text
      end
    end
  end
end
