# frozen_string_literal: true

require "etc"
require "rbconfig"

module Bootprint
  module Collectors
    module OperatingSystem
      TOOLS = %w[git make gcc clang cmake pkg-config docker podman].freeze

      module_function

      def key = "operating_system"

      def capture
        {
          "name" => RbConfig::CONFIG["host_os"],
          "cpu" => RbConfig::CONFIG["host_cpu"],
          "processors" => Etc.nprocessors,
          "capabilities" => TOOLS.to_h { |tool| [tool, executable?(tool)] },
          "ruby_headers" => header_state,
          "ci" => ci_provider
        }
      end

      def executable?(name)
        extensions = Gem.win_platform? ? ENV.fetch("PATHEXT", ".EXE;.BAT;.CMD").split(";") : [""]
        ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? do |directory|
          extensions.any? do |extension|
            File.executable?(File.join(directory, "#{name}#{extension}"))
          end
        end
      end

      def header_state
        path = RbConfig::CONFIG["rubyhdrdir"]
        { "present" => path && File.directory?(path), "path" => path && Sanitizer.path(path) }
      end

      def ci_provider
        return "github" if ENV["GITHUB_ACTIONS"] == "true"
        return "gitlab" if ENV["GITLAB_CI"] == "true"
        return "circleci" if ENV["CIRCLECI"] == "true"
        return "generic" if ENV.key?("CI")

        nil
      end
    end
  end
end
