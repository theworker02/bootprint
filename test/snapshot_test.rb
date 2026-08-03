# frozen_string_literal: true

require_relative "test_helper"

class SnapshotTest < Minitest::Test
  def test_capture_is_schema_v2_and_never_records_environment_values
    previous = ENV.fetch("REDIS_URL", nil)
    ENV["REDIS_URL"] = "redis://user:super-secret@example.test"
    captured = Bootprint::Snapshot.capture(label: "test")
    serialized = JSON.generate(captured.data)

    assert_equal 2, captured.data["schema_version"]
    assert_equal true, captured.environment.dig("configuration", "environment_variables", "REDIS_URL")
    refute_includes serialized, "super-secret"
    refute_includes serialized, ENV.fetch("REDIS_URL", nil)
  ensure
    previous.nil? ? ENV.delete("REDIS_URL") : ENV["REDIS_URL"] = previous
  end

  def test_secret_named_environment_variable_is_presence_only
    previous = ENV.fetch("SECRET_KEY_BASE", nil)
    ENV["SECRET_KEY_BASE"] = "must-never-be-serialized"
    captured = Bootprint::Snapshot.capture(label: "production")
    serialized = JSON.generate(captured.data)

    assert_equal true, captured.environment.dig("configuration", "environment_variables", "SECRET_KEY_BASE")
    refute_includes serialized, "must-never-be-serialized"
  ensure
    previous.nil? ? ENV.delete("SECRET_KEY_BASE") : ENV["SECRET_KEY_BASE"] = previous
  end

  def test_schema_v1_migrates_in_memory_and_preserves_unknown_fields
    legacy = {
      "schema_version" => 1,
      "metadata" => { "captured_at" => "2026-01-01T00:00:00Z", "label" => "legacy" },
      "runtime" => {}, "toolchain" => {}, "gems" => {}, "libraries" => {},
      "environment" => { "variables" => {} }, "operating_system" => {},
      "vendor_extension" => { "kept" => true }
    }
    migrated = Bootprint::Snapshot.new(legacy)

    assert_equal 2, migrated.data["schema_version"]
    assert_equal 1, migrated.data.dig("capture", "migrated_from")
    assert_equal true, migrated.data.dig("extensions", "vendor_extension", "kept")
  end

  def test_future_schema_has_actionable_error
    error = assert_raises(Bootprint::InvalidSnapshotError) do
      Bootprint::Snapshot.new("schema_version" => 99)
    end
    assert_includes error.message, "newer than supported"
  end

  def test_rejects_non_object_and_corrupt_environment
    assert_raises(Bootprint::InvalidSnapshotError) { Bootprint::Snapshot.new([]) }
    invalid = snapshot.data
    invalid["environment"]["configuration"]["environment_variables"] = { "TOKEN" => "value" }
    assert_raises(Bootprint::InvalidSnapshotError) { Bootprint::Snapshot.new(invalid) }
  end

  def test_semantic_data_ignores_timestamp_and_capture_timing
    left = snapshot
    right = snapshot("generated_at" => "2027-01-01T00:00:00Z", "capture" => { "duration_ms" => 999.0 })
    assert_equal left.semantic_data, right.semantic_data
  end

  def test_deterministic_writer_orders_object_keys
    Dir.mktmpdir do |directory|
      path = File.join(directory, "snapshot.json")
      snapshot.write(path)
      parsed = JSON.parse(File.read(path))
      assert_equal parsed.keys.sort, parsed.keys
      assert_equal parsed["environment"].keys.sort, parsed["environment"].keys
    end
  end

  def test_all_declared_platform_fixtures_validate
    names = %w[macos-development linux-ci docker-production windows-development arm64-development x86-64-deployment rails-application
               plain-ruby-gem]
    names.each { |name| assert_equal 2, fixture_snapshot(name).data["schema_version"] }
  end
end
