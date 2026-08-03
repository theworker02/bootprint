# frozen_string_literal: true

require "rbconfig"

module Bootprint
  module Collectors
    module Runtime
      module_function

      def key = "runtime"

      def capture
        {
          "engine" => defined?(RUBY_ENGINE) ? RUBY_ENGINE : "ruby",
          "engine_version" => defined?(RUBY_ENGINE_VERSION) ? RUBY_ENGINE_VERSION : RUBY_VERSION,
          "ruby_version" => RUBY_VERSION,
          "patchlevel" => RUBY_PATCHLEVEL,
          "platform" => RUBY_PLATFORM,
          "architecture" => RbConfig::CONFIG["arch"],
          "host_os" => RbConfig::CONFIG["host_os"],
          "host_cpu" => RbConfig::CONFIG["host_cpu"],
          "description" => RUBY_DESCRIPTION,
          "debug_build" => debug_build?,
          "supported" => Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("3.1.0")
        }
      end

      def debug_build?
        args = RbConfig::CONFIG["configure_args"].to_s
        args.include?("--enable-debug") || args.include?("--with-assertions")
      end
    end
  end
end
