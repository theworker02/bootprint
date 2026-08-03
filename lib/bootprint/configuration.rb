# frozen_string_literal: true

module Bootprint
  class Configuration
    DEFAULT_ENV_PATTERNS = [
      /\A(?:DATABASE|REDIS|RAILS|RACK|BUNDLE|SECRET_KEY_BASE|RAILS_MASTER_KEY)(?:_|\z)/,
      /_URL\z/,
      /_HOST\z/,
      /_PORT\z/
    ].freeze

    attr_accessor :environment_patterns, :environment_names, :ignored_environment_names,
                  :required_environment_names, :optional_environment_names, :privacy,
                  :slow_initializer_threshold_ms, :profile_boot, :plugin_strict,
                  :redaction_patterns, :redaction_safe_list, :expected_platforms

    def initialize
      @environment_patterns = DEFAULT_ENV_PATTERNS.dup
      @environment_names = []
      @ignored_environment_names = []
      @required_environment_names = []
      @optional_environment_names = []
      @privacy = :standard
      @slow_initializer_threshold_ms = 500.0
      @profile_boot = ENV["BOOTPRINT_PROFILE_BOOT"] == "1"
      @plugin_strict = false
      @redaction_patterns = %w[TOKEN SECRET PASSWORD PRIVATE_KEY AUTHORIZATION COOKIE]
      @redaction_safe_list = %w[checksum sha256 digest]
      @expected_platforms = []
    end

    def capture_environment?(name)
      return false if ignored_environment_names.include?(name)

      environment_names.include?(name) || environment_patterns.any? { |pattern| pattern.match?(name) }
    end
  end
end
