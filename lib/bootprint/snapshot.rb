# frozen_string_literal: true

require "json"
require "time"
require "fileutils"
require_relative "collectors/runtime"
require_relative "collectors/toolchain"
require_relative "collectors/gems"
require_relative "collectors/libraries"
require_relative "collectors/environment"
require_relative "collectors/filesystem"
require_relative "collectors/operating_system"
require_relative "collectors/rails"

module Bootprint
  class Snapshot
    SCHEMA_VERSION = Schema::CURRENT_VERSION
    NON_SEMANTIC_PATHS = %w[generated_at capture.duration_ms capture.plugins].freeze

    attr_reader :data

    def self.capture(label: nil, privacy: Bootprint.configuration.privacy)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      Bootprint.configuration.privacy = privacy.to_sym
      warnings = []
      environment = {
        "name" => label,
        "runtime" => safely_collect(Collectors::Runtime, warnings),
        "dependencies" => dependency_data(warnings),
        "native_libraries" => safely_collect(Collectors::Libraries, warnings),
        "configuration" => configuration_data(warnings),
        "filesystem" => safely_collect(Collectors::Filesystem, warnings),
        "operating_system" => safely_collect(Collectors::OperatingSystem, warnings)
      }.compact

      plugin_data = if defined?(Bootprint::Plugins)
                      Bootprint::Plugins.capture(warnings:, strict: Bootprint.configuration.plugin_strict)
                    else
                      {}
                    end
      environment["plugins"] = plugin_data unless plugin_data.empty?
      duration = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1_000
      new({
            "schema_version" => SCHEMA_VERSION,
            "generated_at" => Time.now.utc.iso8601,
            "bootprint_version" => VERSION,
            "environment" => Sanitizer.recursive(environment, privacy:),
            "capture" => {
              "duration_ms" => duration.round(3),
              "privacy" => privacy.to_s,
              "warnings" => warnings
            }
          })
    end

    def self.load(path)
      parsed = JSON.parse(File.read(path, encoding: "UTF-8"))
      new(parsed)
    rescue JSON::ParserError => error
      raise InvalidSnapshotError, "#{File.expand_path(path)} is not valid JSON: #{error.message}"
    rescue Errno::ENOENT
      raise InvalidSnapshotError, "Snapshot not found: #{File.expand_path(path)}"
    end

    def self.safely_collect(collector, warnings)
      collector.capture
    rescue StandardError => error
      warnings << {
        "collector" => collector.key,
        "message" => Sanitizer.text("#{error.class}: #{error.message}"),
        "severity" => "warning"
      }
      { "capture_error" => Sanitizer.text("#{error.class}: #{error.message}") }
    end

    def self.dependency_data(warnings)
      gems = safely_collect(Collectors::Gems, warnings)
      {
        "toolchain" => safely_collect(Collectors::Toolchain, warnings),
        "gems" => gems["resolved"] || {},
        "lockfile" => gems.except("resolved")
      }
    end

    def self.configuration_data(warnings)
      environment = safely_collect(Collectors::Environment, warnings)
      rails = safely_collect(Collectors::Rails, warnings)
      {
        "environment_variables" => environment["variables"] || {},
        "required_environment_variables" => Bootprint.configuration.required_environment_names.sort,
        "optional_environment_variables" => Bootprint.configuration.optional_environment_names.sort,
        "rails" => rails || {}
      }
    end

    def initialize(data)
      migrated = Schema.migrate(Schema.stringify(data))
      Schema.validate!(migrated)
      @data = Schema.deterministic(migrated)
    end

    def write(path)
      directory = File.dirname(File.expand_path(path))
      FileUtils.mkdir_p(directory)
      File.write(path, "#{JSON.pretty_generate(data)}\n")
      path
    end

    def [](key) = data[key.to_s]
    def environment = data["environment"]
    def name = environment["name"] || "unnamed"

    def semantic_data
      Marshal.load(Marshal.dump(data)).tap do |copy|
        copy.delete("generated_at")
        copy.delete("bootprint_version")
        copy["capture"]&.delete("duration_ms")
        copy["capture"]&.delete("warnings")
      end
    end
  end
end
