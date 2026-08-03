# frozen_string_literal: true

require "openssl"
require "psych"
require "rbconfig"

module Bootprint
  module Collectors
    module Libraries
      module_function

      def key = "libraries"

      def capture
        result = {
          "openssl" => {
            "compiled" => OpenSSL::OPENSSL_VERSION,
            "runtime" => OpenSSL.const_defined?(:OPENSSL_LIBRARY_VERSION) ? OpenSSL::OPENSSL_LIBRARY_VERSION : OpenSSL::OPENSSL_VERSION
          },
          "libyaml" => Psych.libyaml_version.join("."),
          "psych" => Psych::VERSION
        }
        result["sqlite"] = sqlite_info if Gem.loaded_specs.key?("sqlite3")
        result["postgresql"] = postgresql_info if Gem.loaded_specs.key?("pg")
        result["mysql"] = mysql_info if Gem.loaded_specs.key?("mysql2")
        result["libc"] = libc_info
        result
      end

      def sqlite_info
        require "sqlite3"
        { "gem" => SQLite3::VERSION, "runtime" => SQLite3::SQLITE_VERSION }
      rescue LoadError, StandardError => error
        { "capture_error" => Sanitizer.text("#{error.class}: #{error.message}") }
      end

      def postgresql_info
        require "pg"
        version = PG.library_version
        { "gem" => PG::VERSION, "client" => format_pg_version(version) }
      rescue LoadError, StandardError => error
        { "capture_error" => Sanitizer.text("#{error.class}: #{error.message}") }
      end

      def format_pg_version(version)
        major = version / 10_000
        minor = (version / 100) % 100
        patch = version % 100
        major >= 10 ? "#{major}.#{patch}" : "#{major}.#{minor}.#{patch}"
      end

      def mysql_info
        require "mysql2"
        info = Mysql2::Client.info
        { "gem" => Mysql2::VERSION, "client" => info[:version] || info["version"] }
      rescue LoadError, StandardError => error
        { "capture_error" => Sanitizer.text("#{error.class}: #{error.message}") }
      end

      def libc_info
        host = RbConfig::CONFIG["host_os"].to_s
        family = if host.include?("linux")
                   RbConfig::CONFIG["CC"].to_s.include?("musl") ? "musl" : "glibc-or-compatible"
                 elsif host.match?(/mswin|mingw/)
                   "windows-crt"
                 elsif host.include?("darwin")
                   "libSystem"
                 else
                   "unknown"
                 end
        { "family" => family }
      end
    end
  end
end
