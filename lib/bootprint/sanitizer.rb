# frozen_string_literal: true

module Bootprint
  module Sanitizer
    REDACTED = "[REDACTED]"
    JWT_PATTERN = /\AeyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\z/
    PRIVATE_KEY_PATTERN = /-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/
    URL_CREDENTIAL_PATTERN = %r{\A([a-z][a-z0-9+.-]*://)([^/@\s]+)@}i
    HIGH_ENTROPY_PATTERN = %r{\A[A-Za-z0-9+/_=-]{32,}\z}

    module_function

    def text(value)
      sanitized = value.to_s.dup
      replacements.each do |path, marker|
        path_variants(path).each do |variant|
          sanitized.gsub!(variant, marker)
        end
      end
      sanitized.gsub(/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/, "?")
    end

    def path(value)
      text(value)
    end

    def recursive(value, patterns: Bootprint.configuration.redaction_patterns, privacy: Bootprint.configuration.privacy)
      case value
      when Hash
        value.each_with_object({}) do |(key, nested), result|
          name = key.to_s
          result[name] = if secret_name?(name, patterns)
                           redaction_metadata(nested)
                         elsif safe_digest_name?(name) && !nested.is_a?(Hash) && !nested.is_a?(Array)
                           nested.to_s
                         else
                           recursive(nested, patterns:, privacy:)
                         end
        end
      when Array
        value.map { |nested| recursive(nested, patterns:, privacy:) }
      when String
        sanitize_value(value, privacy:)
      else
        value
      end
    end

    def secret_name?(name, patterns = Bootprint.configuration.redaction_patterns)
      return false if Bootprint.configuration.redaction_safe_list.any? { |entry| File.fnmatch?(entry, name, File::FNM_CASEFOLD) }

      patterns.any? { |pattern| name.upcase.include?(pattern.to_s.upcase) }
    end

    def safe_digest_name?(name)
      name.match?(/(?:checksum|sha256|digest)\z/i)
    end

    def sensitive_value?(value)
      string = value.to_s
      PRIVATE_KEY_PATTERN.match?(string) || JWT_PATTERN.match?(string) ||
        URL_CREDENTIAL_PATTERN.match?(string) || high_entropy?(string)
    end

    def sanitize_value(value, privacy: :standard)
      result = text(value)
      result = result.gsub(URL_CREDENTIAL_PATTERN, "\\1#{REDACTED}@")
      result = REDACTED if PRIVATE_KEY_PATTERN.match?(result) || JWT_PATTERN.match?(result) || high_entropy?(result)
      result = "<HOST>" if privacy.to_sym == :strict && hostname_like?(result)
      result
    end

    def high_entropy?(value)
      return false unless HIGH_ENTROPY_PATTERN.match?(value)

      value.chars.uniq.length >= 16
    end

    def hostname_like?(value)
      value.match?(/\A(?=.{1,253}\z)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}\z/i)
    end

    def redaction_metadata(value)
      { "present" => !value.nil?, "redacted" => true }
    end

    def replacements
      app_root = File.expand_path(Dir.pwd)
      home = begin
        File.expand_path(Dir.home)
      rescue ArgumentError
        nil
      end
      [[app_root, "<APP_ROOT>"], [home, "<HOME>"]].reject { |path, _marker| path.nil? || path.empty? }
    end

    def path_variants(path)
      [path, path.tr("\\", "/"), path.tr("/", "\\")].uniq.sort_by { |variant| -variant.length }
    end
  end
end
