# frozen_string_literal: true

require_relative "test_helper"

class RulesTest < Minitest::Test
  def test_at_least_25_complete_builtin_rules_are_registered
    rules = Bootprint::Rules::Registry.all
    assert_operator rules.length, :>=, 25
    rules.each do |rule|
      refute_empty rule.id
      refute_empty rule.name
      assert_includes Bootprint::Rules::Rule::SEVERITIES, rule.severity
      assert_equal true, rule.metadata_value["built_in"]
    end
  end

  def test_runtime_rule_produces_actionable_structured_finding
    report = Bootprint::Diagnosis.new(fixture_snapshot("macos-development"), fixture_snapshot("linux-ci")).run
    finding = report.findings.find { |candidate| candidate.rule_id == "ruby-version-drift" }

    assert_equal :error, finding.severity
    assert_equal "3.4.2", finding.evidence["source"]
    assert_equal "3.4.1", finding.evidence["target"]
    refute_empty finding.impact
    refute_empty finding.remediation["summary"]
    assert_includes finding.remediation["files"], ".ruby-version"
  end

  def test_native_platform_rule_is_critical
    report = Bootprint::Diagnosis.new(fixture_snapshot("macos-development"), fixture_snapshot("docker-production")).run
    finding = report.findings.find { |candidate| candidate.rule_id == "architecture-specific-gem-incompatibility" }
    assert_equal :critical, finding.severity
    assert_equal "nokogiri", finding.evidence["gems"].first["name"]
  end

  def test_custom_rule_uses_phase2_dsl_without_rails
    Bootprint::Rules.define "custom-runtime-check" do
      name "Custom runtime check"
      category :runtime
      severity :info
      detect { |_source, _target| { "checked" => true } }
      explain { |_source, _target, evidence| { summary: "Custom check ran.", evidence: evidence } }
      remediate "No action required."
      metadata provider: "test"
    end
    finding = Bootprint::Rules::Registry.fetch("custom-runtime-check").evaluate(snapshot, snapshot, policy: Bootprint::Policy.new)
    assert_equal "Custom check ran.", finding.summary
    assert_equal :runtime, finding.category
  ensure
    Bootprint::Rules::Registry.rules.reject! { |rule| rule.id == "custom-runtime-check" }
  end

  def test_initializer_heuristic_rules_use_profile_metadata
    target = snapshot(
      "environment" => {
        "configuration" => {
          "rails" => {
            "initializers" => [{
              "name" => "config/initializers/payments.rb",
              "duration_ms" => 900.0,
              "missing_environment_variables" => ["PAYMENTS_URL"],
              "network_operation_heuristic" => true,
              "configuration_mutation_heuristic" => true,
              "configuration_mutations" => ["eager_load"]
            }]
          }
        }
      }
    )
    ids = Bootprint::Diagnosis.new(target, target).run.findings.map(&:rule_id)
    assert_includes ids, "slow-rails-initializer"
    assert_includes ids, "initializer-network-operation"
    assert_includes ids, "initializer-missing-environment-variable"
    assert_includes ids, "initializer-global-configuration-mutation"
  end
end
