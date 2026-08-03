# frozen_string_literal: true

module Bootprint
  module Schema
    CURRENT_VERSION = 2
    ENVIRONMENT_SECTIONS = %w[runtime dependencies native_libraries configuration filesystem operating_system].freeze

    module_function

    def migrate(data)
      raise InvalidSnapshotError, "Snapshot root must be a JSON object" unless data.is_a?(Hash)

      version = data.is_a?(Hash) ? data["schema_version"] || data[:schema_version] : nil
      case version
      when CURRENT_VERSION then stringify(data)
      when 1 then migrate_v1(stringify(data))
      when nil then raise InvalidSnapshotError, "Snapshot does not declare schema_version"
      else
        if version.is_a?(Integer) && version > CURRENT_VERSION
          raise InvalidSnapshotError, "Snapshot schema #{version} is newer than supported schema #{CURRENT_VERSION}; upgrade Bootprint"
        end

        raise InvalidSnapshotError, "Unsupported snapshot schema #{version.inspect}"
      end
    end

    def validate!(data)
      raise InvalidSnapshotError, "Snapshot root must be a JSON object" unless data.is_a?(Hash)
      raise InvalidSnapshotError, "schema_version must equal #{CURRENT_VERSION}" unless data["schema_version"] == CURRENT_VERSION
      raise InvalidSnapshotError, "generated_at must be an ISO-8601 string" unless data["generated_at"].is_a?(String)
      raise InvalidSnapshotError, "bootprint_version must be a string" unless data["bootprint_version"].is_a?(String)

      environment = data["environment"]
      raise InvalidSnapshotError, "environment must be an object" unless environment.is_a?(Hash)

      missing = ENVIRONMENT_SECTIONS - environment.keys
      raise InvalidSnapshotError, "environment is missing sections: #{missing.join(', ')}" unless missing.empty?

      invalid = ENVIRONMENT_SECTIONS.reject { |key| environment[key].is_a?(Hash) }
      raise InvalidSnapshotError, "environment sections must be objects: #{invalid.join(', ')}" unless invalid.empty?

      variables = environment.dig("configuration", "environment_variables")
      unless variables.is_a?(Hash) && variables.values.all? { |value| [true, false].include?(value) }
        raise InvalidSnapshotError, "configuration.environment_variables must map names to booleans"
      end

      true
    end

    def migrate_v1(old)
      known = %w[schema_version metadata runtime toolchain gems libraries environment operating_system rails]
      unknown = old.except(*known)
      rails = old["rails"] || {}
      {
        "schema_version" => CURRENT_VERSION,
        "generated_at" => old.dig("metadata", "captured_at") || Time.now.utc.iso8601,
        "bootprint_version" => VERSION,
        "environment" => {
          "name" => old.dig("metadata", "label"),
          "runtime" => old["runtime"] || {},
          "dependencies" => {
            "toolchain" => old["toolchain"] || {},
            "gems" => old.dig("gems", "resolved") || {},
            "lockfile" => { "sha256" => old.dig("gems", "lockfile_sha256"), "platforms" => [] }.compact
          },
          "native_libraries" => old["libraries"] || {},
          "configuration" => {
            "environment_variables" => old.dig("environment", "variables") || {},
            "required_environment_variables" => [],
            "optional_environment_variables" => [],
            "rails" => rails
          },
          "filesystem" => default_filesystem,
          "operating_system" => old["operating_system"] || {}
        }.compact,
        "capture" => { "migrated_from" => 1 },
        "extensions" => unknown
      }
    end

    def default_filesystem
      {
        "path_separator" => File::ALT_SEPARATOR || File::SEPARATOR,
        "temporary_directory" => { "present" => true, "writable" => true },
        "required_directories" => {}
      }
    end

    def stringify(value)
      case value
      when Hash then value.to_h { |key, nested| [key.to_s, stringify(nested)] }
      when Array then value.map { |nested| stringify(nested) }
      else value
      end
    end

    def deterministic(value)
      case value
      when Hash then value.keys.sort.to_h { |key| [key, deterministic(value[key])] }
      when Array
        normalized = value.map { |nested| deterministic(nested) }
        normalized.all? { |item| scalar?(item) } ? normalized.sort_by(&:to_s) : normalized
      else value
      end
    end

    def scalar?(value)
      value.nil? || value.is_a?(String) || value.is_a?(Numeric) || value == true || value == false
    end
  end
end
