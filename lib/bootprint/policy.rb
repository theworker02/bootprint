# frozen_string_literal: true

require "yaml"

module Bootprint
  class Policy
    MODES = %w[permissive strict].freeze
    SEVERITIES = %w[info warning error critical].freeze
    TOP_LEVEL_KEYS = %w[version minimum_severity fail_on ignore allow rules redaction mode expected_platforms plugins].freeze

    attr_reader :path, :data

    def self.load(path = nil)
      return new(nil, {}) unless path

      absolute = File.expand_path(path)
      raise ConfigurationError, "#{absolute}: file not found" unless File.file?(absolute)

      parsed = YAML.safe_load_file(absolute, permitted_classes: [], aliases: false) || {}
      new(absolute, parsed)
    rescue Psych::SyntaxError => error
      raise ConfigurationError, "#{absolute}:#{error.line}:#{error.column}: #{error.problem}"
    rescue Psych::Exception => error
      raise ConfigurationError, "#{absolute}: #{error.message}"
    end

    def initialize(path = nil, data = {})
      @path = path
      @data = Schema.stringify(data)
      validate!
    end

    def minimum_severity
      (data["minimum_severity"] || (strict? ? "warning" : "info")).to_sym
    end

    def fail_on
      Array(data["fail_on"] || (strict? ? %w[warning error critical] : %w[error critical])).map(&:to_s)
    end

    def expected_platforms
      Array(data["expected_platforms"]).map(&:to_s)
    end

    def optional_environment_variables
      allow = data["allow"]
      return [] unless allow.is_a?(Hash)

      Array(allow["environment_variables"]).map(&:to_s)
    end

    def optional_environment_variable?(name)
      optional_environment_variables.include?(name.to_s)
    end

    def allowed_paths
      allow = data["allow"]
      if allow.is_a?(Array)
        allow.map(&:to_s)
      else
        Array(allow.is_a?(Hash) ? allow["paths"] : nil).map(&:to_s)
      end
    end

    def redaction_patterns
      Array(data.dig("redaction", "patterns")).map(&:to_s)
    end

    def redaction_safe_list
      Array(data.dig("redaction", "safe_list")).map(&:to_s)
    end

    def plugin_strict?
      strict? || data.dig("plugins", "strict") == true
    end

    def strict? = data.fetch("mode", "permissive") == "strict"

    def ignored?(rule_id)
      Array(data["ignore"]).map(&:to_s).include?(rule_id.to_s)
    end

    def disabled?(rule_id)
      data.dig("rules", rule_id.to_s, "enabled") == false
    end

    def severity_for(rule_id, default)
      (data.dig("rules", rule_id.to_s, "severity") || default).to_sym
    end

    def suppression_reason(rule_id)
      return "ignored by policy" if ignored?(rule_id)
      return "disabled by policy" if disabled?(rule_id)

      nil
    end

    def apply!
      Bootprint.configuration.optional_environment_names |= optional_environment_variables
      Bootprint.configuration.expected_platforms = expected_platforms
      Bootprint.configuration.redaction_patterns |= redaction_patterns
      Bootprint.configuration.redaction_safe_list |= redaction_safe_list
      Bootprint.configuration.plugin_strict = plugin_strict?
      self
    end

    def explain
      lines = []
      lines << "Policy: #{path || '(built-in defaults)'}"
      lines << "Mode: #{strict? ? 'strict' : 'permissive'}"
      lines << "Minimum reported severity: #{minimum_severity}"
      lines << "Blocking severities: #{fail_on.join(', ')}"
      lines << "Ignored rules: #{Array(data['ignore']).join(', ')}" unless Array(data["ignore"]).empty?
      lines << "Optional environment variables: #{optional_environment_variables.join(', ')}" unless optional_environment_variables.empty?
      lines << "Expected platforms: #{expected_platforms.join(', ')}" unless expected_platforms.empty?
      lines << "Rule overrides: #{Array(data['rules']&.keys).join(', ')}" if data["rules"].is_a?(Hash)
      "#{lines.join("\n")}\n"
    end

    private

    def validate!
      error("policy root must be a mapping") unless data.is_a?(Hash)
      unknown = data.keys - TOP_LEVEL_KEYS
      error("unknown keys: #{unknown.join(', ')}", unknown.first) unless unknown.empty?
      error("version must equal 1", "version") unless data.fetch("version", 1) == 1
      validate_severity(data["minimum_severity"], "minimum_severity") if data["minimum_severity"]
      unless Array(data["fail_on"]).all? { |severity| SEVERITIES.include?(severity.to_s) }
        error("fail_on contains an invalid severity", "fail_on")
      end
      mode = data.fetch("mode", "permissive")
      error("mode must be strict or permissive", "mode") unless MODES.include?(mode)
      error("ignore must be an array", "ignore") if data.key?("ignore") && !data["ignore"].is_a?(Array)
      error("rules must be a mapping", "rules") if data.key?("rules") && !data["rules"].is_a?(Hash)
      validate_rule_overrides
      validate_allow
      validate_redaction
    end

    def validate_rule_overrides
      return unless data["rules"].is_a?(Hash)

      data["rules"].each do |id, settings|
        error("rule #{id} must be a mapping", id) unless settings.is_a?(Hash)
        unknown = settings.keys - %w[enabled severity]
        error("rule #{id} has unknown settings: #{unknown.join(', ')}", id) unless unknown.empty?
        validate_severity(settings["severity"], id) if settings["severity"]
        error("rule #{id} enabled must be true or false", id) if settings.key?("enabled") && ![true, false].include?(settings["enabled"])
      end
    end

    def validate_allow
      allow = data["allow"]
      return if allow.nil? || allow.is_a?(Array)

      error("allow must be a mapping or legacy array", "allow") unless allow.is_a?(Hash)
      unknown = allow.keys - %w[environment_variables paths]
      error("allow has unknown settings: #{unknown.join(', ')}", "allow") unless unknown.empty?
      allow.each { |key, value| error("allow.#{key} must be an array", key) unless value.is_a?(Array) }
    end

    def validate_redaction
      redaction = data["redaction"]
      return unless redaction

      error("redaction must be a mapping", "redaction") unless redaction.is_a?(Hash)
      unknown = redaction.keys - %w[patterns safe_list]
      error("redaction has unknown settings: #{unknown.join(', ')}", "redaction") unless unknown.empty?
      redaction.each do |key, value|
        error("redaction.#{key} must be an array", key) unless value.is_a?(Array) && value.all?(String)
      end
    end

    def validate_severity(value, key)
      error("#{key} must be one of #{SEVERITIES.join(', ')}", key) unless SEVERITIES.include?(value.to_s)
    end

    def error(message, key = nil)
      location = path || ".bootprint.yml"
      line = key && source_line(key)
      raise ConfigurationError, "#{location}#{":#{line}" if line}: #{message}"
    end

    def source_line(key)
      return unless path && File.file?(path)

      pattern = /^\s*#{Regexp.escape(key.to_s)}\s*:/
      File.readlines(path, encoding: "UTF-8").index { |line| line.match?(pattern) }&.+(1)
    end
  end
end
