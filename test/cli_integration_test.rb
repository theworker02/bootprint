# frozen_string_literal: true

require_relative "test_helper"

class CLIIntegrationTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  EXECUTABLE = File.join(ROOT, "exe", "bootprint")
  LIB = File.join(ROOT, "lib")

  def run_cli(*arguments, chdir: ROOT, env: {})
    Open3.capture3(env, RbConfig.ruby, "-I#{LIB}", EXECUTABLE, *arguments, chdir:)
  end

  def test_actual_cli_captures_validates_and_inspects_snapshot
    Dir.mktmpdir do |directory|
      output = File.join(directory, "local.json")
      stdout, stderr, status = run_cli("capture", "local", "--output", output, "--privacy", "strict", chdir: directory)
      assert status.success?, stderr
      assert_includes stdout, "schema-v2"

      stdout, stderr, status = run_cli("snapshot", "validate", output, chdir: directory)
      assert status.success?, stderr
      assert_includes stdout, "schema 2"

      stdout, stderr, status = run_cli("snapshot", "inspect", output, chdir: directory)
      assert status.success?, stderr
      assert_equal 2, JSON.parse(stdout)["schema_version"]
    end
  end

  def test_actual_diagnose_emits_structured_json_and_policy_exit
    source = File.join(FIXTURES, "macos-development.json")
    target = File.join(FIXTURES, "linux-ci.json")
    stdout, stderr, status = run_cli("diagnose", source, target, "--format", "json")
    report = JSON.parse(stdout)

    assert_equal 1, status.exitstatus, stderr
    assert_equal 1, report["schema_version"]
    assert(report["findings"].any? { |finding| finding["rule_id"] == "missing-environment-variable" })
    assert(report["findings"].all? { |finding| finding.key?("remediation") && finding.key?("evidence") })
  end

  def test_actual_diagnose_supports_markdown_and_filters
    source = File.join(FIXTURES, "macos-development.json")
    target = File.join(FIXTURES, "linux-ci.json")
    stdout, _stderr, _status = run_cli("diagnose", source, target, "--format", "markdown", "--only", "runtime", "--minimum-severity",
                                       "warning")
    assert_includes stdout, "# Bootprint Diagnosis"
    assert_includes stdout, "Ruby version mismatch"
    refute_includes stdout, "Required environment variable"
  end

  def test_fix_is_preview_only_and_requires_dry_run
    _stdout, _stderr, status = run_cli("fix")
    assert_equal 2, status.exitstatus

    ruby_version_path = File.join(ROOT, ".ruby-version")
    ruby_version_before = File.binread(ruby_version_path)
    source = File.join(FIXTURES, "macos-development.json")
    stdout, stderr, status = run_cli("fix", "--dry-run", "--against", source)
    assert status.success?, stderr
    assert_includes stdout, "no commands executed"
    assert_equal ruby_version_before, File.binread(ruby_version_path)
  end

  def test_policy_commands_use_real_file
    Dir.mktmpdir do |directory|
      policy = File.join(directory, ".bootprint.yml")
      File.write(policy, "version: 1\nmode: permissive\n")
      stdout, stderr, status = run_cli("policy", "validate", "--file", policy, chdir: directory)
      assert status.success?, stderr
      assert_includes stdout, "Policy is valid"
      stdout, = run_cli("policy", "explain", "--file", policy, chdir: directory)
      assert_includes stdout, "Mode: permissive"
    end
  end

  def test_snapshot_migrate_writes_a_new_file_without_overwriting_source
    Dir.mktmpdir do |directory|
      source = File.join(directory, "old.json")
      output = File.join(directory, "new.json")
      legacy = {
        schema_version: 1, metadata: { captured_at: "2026-01-01T00:00:00Z" }, runtime: {}, toolchain: {},
        gems: {}, libraries: {}, environment: { variables: {} }, operating_system: {}
      }
      File.write(source, JSON.generate(legacy))
      _stdout, stderr, status = run_cli("snapshot", "migrate", source, "--output", output, chdir: directory)
      assert status.success?, stderr
      assert_equal 1, JSON.parse(File.read(source))["schema_version"]
      assert_equal 2, JSON.parse(File.read(output))["schema_version"]
    end
  end

  def test_docker_unavailable_is_reported_without_touching_containers
    _stdout, stderr, status = run_cli("docker", "capture", "example:latest", env: { "PATH" => "" })
    assert_equal 4, status.exitstatus
    assert_includes stderr, "Docker is unavailable"
  end

  def test_github_ci_emits_annotations_and_job_summary
    Dir.mktmpdir do |directory|
      summary = File.join(directory, "summary.md")
      source = File.join(FIXTURES, "macos-development.json")
      env = { "GITHUB_ACTIONS" => "true", "GITHUB_STEP_SUMMARY" => summary }
      stdout, stderr, status = run_cli("ci", "verify", "--against", source, env:)
      assert_equal 1, status.exitstatus, stderr
      assert_includes stdout, "::error title="
      assert_includes File.read(summary), "# Bootprint Diagnosis"
    end
  end
end
