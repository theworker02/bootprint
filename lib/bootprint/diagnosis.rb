# frozen_string_literal: true

module Bootprint
  class Diagnosis
    REPORT_SCHEMA_VERSION = 1
    attr_reader :source, :target, :policy, :only, :minimum_severity

    def initialize(source, target, policy: Policy.new, only: nil, minimum_severity: nil)
      @source = source
      @target = target
      @policy = policy
      @only = only
      @minimum_severity = minimum_severity
    end

    def run
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      findings = Rules.evaluate(source, target, policy:, only:, minimum_severity:)
      findings.concat(plugin_failure_findings(target))
      duration = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1_000
      Report.new(source:, target:, findings:, policy:, duration_ms: duration.round(3))
    end

    private

    def plugin_failure_findings(snapshot)
      warnings = snapshot.data.dig("capture", "warnings") || []
      warnings.filter_map do |warning|
        next unless warning["plugin"]

        severity = policy.plugin_strict? ? :error : :warning
        Rules::Finding.new(
          rule_id: "plugin-capture-failure",
          title: "Bootprint plugin failed",
          category: :plugins,
          severity:,
          summary: "Plugin #{warning['plugin']} could not capture its data.",
          cause: warning["message"],
          impact: "Plugin-specific diagnostics are incomplete; the core snapshot remains valid.",
          evidence: warning,
          remediation: { "summary" => "Update, reconfigure, or disable the failing plugin.", "commands" => [], "files" => [] },
          references: [], metadata: { "built_in" => true }, suppressed: false
        )
      end
    end
  end

  class Report
    attr_reader :source, :target, :findings, :policy, :duration_ms

    def initialize(source:, target:, findings:, policy:, duration_ms:)
      @source = source
      @target = target
      @findings = findings.sort_by { |finding| [-Rules::SEVERITY_ORDER.fetch(finding.severity), finding.rule_id] }
      @policy = policy
      @duration_ms = duration_ms
    end

    def blocking? = findings.any? { |finding| finding.blocking?(policy) }

    def counts
      Rules::Rule::SEVERITIES.to_h { |severity| [severity.to_s, findings.count { |finding| finding.severity == severity && !finding.suppressed }] }
    end

    def to_h
      {
        "schema_version" => Diagnosis::REPORT_SCHEMA_VERSION,
        "source" => snapshot_metadata(source),
        "target" => snapshot_metadata(target),
        "findings" => findings.map(&:to_h),
        "summary" => counts.merge("blocking" => blocking?),
        "execution" => {
          "bootprint_version" => VERSION,
          "duration_ms" => duration_ms,
          "network_requests" => 0,
          "policy" => policy.path
        }
      }
    end

    private

    def snapshot_metadata(snapshot)
      {
        "name" => snapshot.name,
        "schema_version" => snapshot.data["schema_version"],
        "generated_at" => snapshot.data["generated_at"],
        "bootprint_version" => snapshot.data["bootprint_version"]
      }
    end
  end
end
