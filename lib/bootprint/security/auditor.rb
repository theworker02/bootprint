# frozen_string_literal: true

module Bootprint
  module Security
    class Auditor
      Issue = Struct.new(:path, :kind, :message, keyword_init: true) do
        def to_h = { "path" => path, "kind" => kind, "message" => message }
      end

      def initialize(snapshot)
        @snapshot = snapshot
      end

      def audit
        issues = []
        walk(@snapshot.data, [], issues)
        issues
      end

      private

      def walk(value, path, issues)
        case value
        when Hash
          value.each do |key, nested|
            current = path + [key]
            if Sanitizer.secret_name?(key) && !presence_boolean?(nested) && !redacted_metadata?(nested)
              issues << Issue.new(path: current.join("."), kind: "secret-name",
                                  message: "Secret-like field is not represented by redaction metadata.")
            end
            walk(nested, current, issues)
          end
        when Array
          value.each_with_index { |nested, index| walk(nested, path + [index], issues) }
        when String
          return if Sanitizer.safe_digest_name?(path.last.to_s)

          if Sanitizer.sensitive_value?(value)
            issues << Issue.new(path: path.join("."), kind: "sensitive-value",
                                message: "Value resembles a credential, token, private key, or credential-bearing URL.")
          elsif absolute_home_path?(value)
            issues << Issue.new(path: path.join("."), kind: "home-path", message: "Absolute user-home path was not normalized.")
          end
        end
      end

      def redacted_metadata?(value)
        value.is_a?(Hash) && value["redacted"] == true && value.keys.all? { |key| %w[present source redacted].include?(key) }
      end

      def presence_boolean?(value)
        [true, false].include?(value)
      end

      def absolute_home_path?(value)
        home = File.expand_path(Dir.home)
        value.include?(home) || value.include?(home.tr("\\", "/"))
      rescue ArgumentError
        false
      end
    end
  end
end
