# frozen_string_literal: true

require_relative "test_helper"
require "bootprint/security/auditor"

class SecurityAuditorTest < Minitest::Test
  def test_detects_injected_sensitive_value_but_allows_presence_metadata
    data = snapshot.data
    data["extensions"] = {
      "leak" => "postgres://admin:password@example.test/db",
      "API_TOKEN" => "not-redacted"
    }
    data["environment"]["configuration"]["environment_variables"]["SECRET_KEY_BASE"] = true
    issues = Bootprint::Security::Auditor.new(Bootprint::Snapshot.new(data)).audit

    assert(issues.any? { |issue| issue.path == "extensions.leak" })
    assert(issues.any? { |issue| issue.path == "extensions.API_TOKEN" })
    refute(issues.any? { |issue| issue.path.include?("environment_variables.SECRET_KEY_BASE") })
  end

  def test_captured_snapshot_passes_audit
    assert_empty Bootprint::Security::Auditor.new(Bootprint::Snapshot.capture).audit
  end
end
