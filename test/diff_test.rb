# frozen_string_literal: true

require_relative "test_helper"

class DiffTest < Minitest::Test
  def test_flattens_nested_changes_and_ignores_nonsemantic_metadata
    target = snapshot(
      "generated_at" => "2027-01-01T00:00:00Z",
      "environment" => { "name" => "production", "runtime" => { "ruby_version" => "3.3.7" } }
    )
    assert_equal ["environment.runtime.ruby_version"], Bootprint::Diff.new(snapshot, target).changes.map(&:path)
  end

  def test_allowed_glob_removes_expected_drift
    local = snapshot("environment" => { "configuration" => { "environment_variables" => { "REDIS_URL" => true } } })
    changes = Bootprint::Diff.new(local, snapshot, allowed_paths: ["environment.configuration.environment_variables.*"]).changes
    assert_empty changes
  end
end
