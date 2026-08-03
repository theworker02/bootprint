# frozen_string_literal: true

require_relative "test_helper"

class DiagnosisTest < Minitest::Test
  def test_missing_environment_variable_has_remediation_and_blocks
    report = Bootprint::Diagnosis.new(fixture_snapshot("macos-development"), fixture_snapshot("linux-ci")).run
    finding = report.findings.find { |candidate| candidate.rule_id == "missing-environment-variable" }

    assert_equal :error, finding.severity
    assert_includes finding.evidence["variables"], "REDIS_URL"
    refute_empty finding.remediation["summary"]
    assert report.blocking?
    refute(report.findings.any? { |candidate| candidate.rule_id == "environment-variable-local-only" })
  end

  def test_policy_suppression_and_severity_override_are_preserved_in_report
    policy = Bootprint::Policy.new(nil, {
                                     "ignore" => ["ruby-version-drift"],
                                     "rules" => { "missing-environment-variable" => { "severity" => "critical" } }
                                   })
    report = Bootprint::Diagnosis.new(fixture_snapshot("macos-development"), fixture_snapshot("linux-ci"), policy:).run
    ruby = report.findings.find { |finding| finding.rule_id == "ruby-version-drift" }
    env = report.findings.find { |finding| finding.rule_id == "missing-environment-variable" }

    assert ruby.suppressed
    assert_equal "ignored by policy", ruby.suppression_reason
    assert_equal :critical, env.severity
  end

  def test_category_and_minimum_severity_filters
    report = Bootprint::Diagnosis.new(
      fixture_snapshot("macos-development"), fixture_snapshot("linux-ci"),
      only: ["runtime"], minimum_severity: "error"
    ).run
    assert(report.findings.all? { |finding| finding.category == :runtime })
    assert(report.findings.all? { |finding| Bootprint::Rules::SEVERITY_ORDER[finding.severity] >= 2 })
  end

  def test_same_snapshot_has_no_spurious_findings
    current = snapshot
    report = Bootprint::Diagnosis.new(current, current).run
    assert_empty report.findings
  end

  def test_disabled_rule_remains_machine_visible_but_does_not_block
    source = snapshot
    target = snapshot("environment" => { "runtime" => { "ruby_version" => "3.3.0" } })
    policy = Bootprint::Policy.new(nil, "rules" => { "ruby-version-drift" => { "enabled" => false } })
    finding = Bootprint::Diagnosis.new(source, target, policy:).run.findings.find { |item| item.rule_id == "ruby-version-drift" }
    assert finding.suppressed
    refute finding.blocking?(policy)
  end
end
