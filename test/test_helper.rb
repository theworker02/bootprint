# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "stringio"
require "open3"
require "rbconfig"
require "bootprint"

module SnapshotHelpers
  FIXTURES = File.expand_path("fixtures/snapshots", __dir__)

  def snapshot(overrides = {})
    base = {
      "schema_version" => 2,
      "generated_at" => "2026-08-02T21:00:00Z",
      "bootprint_version" => Bootprint::VERSION,
      "environment" => {
        "name" => "local",
        "runtime" => {
          "engine" => "ruby", "engine_version" => "3.4.2", "ruby_version" => "3.4.2",
          "patchlevel" => 20, "platform" => "x86_64-linux", "architecture" => "x86_64-linux",
          "debug_build" => false, "supported" => true
        },
        "dependencies" => {
          "toolchain" => { "bundler_version" => "4.0.0", "rubygems_version" => "4.0.0" },
          "gems" => {}, "lockfile" => { "platforms" => ["x86_64-linux"], "git_sources" => [], "path_sources" => [] }
        },
        "native_libraries" => { "openssl" => { "runtime" => "OpenSSL 3.4.0" }, "libyaml" => "0.2.5" },
        "configuration" => {
          "environment_variables" => {}, "required_environment_variables" => [],
          "optional_environment_variables" => [], "rails" => {}
        },
        "filesystem" => {
          "path_separator" => "/", "case_sensitive" => true, "symlinks_supported" => true,
          "temporary_directory" => { "present" => true, "writable" => true }, "required_directories" => {}
        },
        "operating_system" => {
          "name" => "linux", "cpu" => "x86_64", "capabilities" => { "make" => true, "gcc" => true },
          "ruby_headers" => { "present" => true }
        }
      },
      "capture" => { "duration_ms" => 12.3, "privacy" => "standard", "warnings" => [] }
    }
    Bootprint::Snapshot.new(deep_merge(base, overrides))
  end

  def fixture_snapshot(name)
    Bootprint::Snapshot.load(File.join(FIXTURES, "#{name}.json"))
  end

  def deep_merge(left, right)
    left.merge(right) do |_key, old_value, new_value|
      old_value.is_a?(Hash) && new_value.is_a?(Hash) ? deep_merge(old_value, new_value) : new_value
    end
  end
end

class Minitest::Test
  include SnapshotHelpers

  def setup
    Bootprint.configuration.environment_patterns = Bootprint::Configuration::DEFAULT_ENV_PATTERNS.dup
    Bootprint.configuration.environment_names = []
    Bootprint.configuration.ignored_environment_names = []
    Bootprint.configuration.required_environment_names = []
    Bootprint.configuration.optional_environment_names = []
    Bootprint.configuration.privacy = :standard
    Bootprint.configuration.redaction_patterns = %w[TOKEN SECRET PASSWORD PRIVATE_KEY AUTHORIZATION COOKIE]
    Bootprint.configuration.redaction_safe_list = %w[checksum sha256 digest]
    Bootprint.configuration.expected_platforms = []
    Bootprint.configuration.plugin_strict = false
    Bootprint::Plugins.reset!
  end
end
