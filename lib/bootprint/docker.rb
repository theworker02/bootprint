# frozen_string_literal: true

require "json"
require "open3"
require "securerandom"

module Bootprint
  module Docker
    class Client
      CAPTURE_SCRIPT = <<~'RUBY'
        require "json"
        require "rbconfig"
        require "rubygems"
        require "openssl"
        require "psych"
        packages = []
        if File.file?("/var/lib/dpkg/status")
          packages = File.read("/var/lib/dpkg/status").scan(/^Package:\s*(\S+)/).flatten
        elsif File.file?("/lib/apk/db/installed")
          packages = File.read("/lib/apk/db/installed").scan(/^P:(\S+)/).flatten
        end
        gems = Gem::Specification.map do |spec|
          [spec.name, {
            "version" => spec.version.to_s,
            "platform" => spec.platform.to_s,
            "native_extensions" => !spec.extensions.empty?,
            "missing_extensions" => spec.respond_to?(:missing_extensions?) && spec.missing_extensions?,
            "prerelease" => spec.version.prerelease?
          }]
        end.sort.to_h
        output = {
          "runtime" => {
            "engine" => defined?(RUBY_ENGINE) ? RUBY_ENGINE : "ruby",
            "engine_version" => defined?(RUBY_ENGINE_VERSION) ? RUBY_ENGINE_VERSION : RUBY_VERSION,
            "ruby_version" => RUBY_VERSION,
            "patchlevel" => RUBY_PATCHLEVEL,
            "platform" => RUBY_PLATFORM,
            "architecture" => RbConfig::CONFIG["arch"],
            "host_os" => RbConfig::CONFIG["host_os"],
            "host_cpu" => RbConfig::CONFIG["host_cpu"],
            "description" => RUBY_DESCRIPTION,
            "debug_build" => RbConfig::CONFIG["configure_args"].to_s.include?("--enable-debug"),
            "supported" => Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("3.1.0")
          },
          "dependencies" => {
            "toolchain" => {
              "rubygems_version" => Gem::VERSION,
              "bundler_version" => Gem.loaded_specs["bundler"]&.version&.to_s
            },
            "gems" => gems,
            "lockfile" => { "platforms" => [] }
          },
          "native_libraries" => {
            "openssl" => {
              "compiled" => OpenSSL::OPENSSL_VERSION,
              "runtime" => OpenSSL.const_defined?(:OPENSSL_LIBRARY_VERSION) ? OpenSSL::OPENSSL_LIBRARY_VERSION : OpenSSL::OPENSSL_VERSION
            },
            "libyaml" => Psych.libyaml_version.join("."),
            "psych" => Psych::VERSION
          },
          "configuration" => {
            "environment_variables" => ENV.keys.sort.to_h { |name| [name, true] },
            "required_environment_variables" => [],
            "optional_environment_variables" => [],
            "rails" => {}
          },
          "filesystem" => {
            "path_separator" => File::SEPARATOR,
            "case_sensitive" => true,
            "symlinks_supported" => File.respond_to?(:symlink),
            "temporary_directory" => { "present" => File.directory?("/tmp"), "writable" => File.writable?("/tmp"), "path" => "/tmp" },
            "required_directories" => { "current" => { "present" => File.directory?(Dir.pwd), "writable" => File.writable?(Dir.pwd), "path" => Dir.pwd } }
          },
          "operating_system" => {
            "name" => RbConfig::CONFIG["host_os"],
            "cpu" => RbConfig::CONFIG["host_cpu"],
            "capabilities" => {
              "make" => ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? { |dir| File.executable?(File.join(dir, "make")) },
              "gcc" => ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? { |dir| File.executable?(File.join(dir, "gcc")) }
            },
            "ruby_headers" => { "present" => File.directory?(RbConfig::CONFIG["rubyhdrdir"].to_s) },
            "system_packages" => packages.sort
          }
        }
        STDOUT.write(JSON.generate(output))
      RUBY

      def available?
        _out, _error, status = Open3.capture3("docker", "version", "--format", "{{.Client.Version}}")
        status.success?
      rescue Errno::ENOENT
        false
      end

      def capture(image, label: nil, privacy: :standard)
        raise DockerError, "Docker is unavailable; install Docker and ensure its daemon is running" unless available?

        metadata = image_metadata(image)
        container_name = "bootprint-#{SecureRandom.hex(8)}"
        stdout, stderr, status = Open3.capture3(
          "docker", "run", "--name", container_name, "--rm", "--network", "none", "--read-only", "--entrypoint", "ruby",
          image.to_s, "-e", CAPTURE_SCRIPT
        )
        raise DockerError, "Could not inspect image #{image}: #{Sanitizer.text(stderr.strip)}" unless status.success?

        environment = JSON.parse(stdout)
        environment["name"] = label || image.to_s
        environment["container"] = metadata
        Snapshot.new(
          "schema_version" => Schema::CURRENT_VERSION,
          "generated_at" => Time.now.utc.iso8601,
          "bootprint_version" => VERSION,
          "environment" => Sanitizer.recursive(environment, privacy:),
          "capture" => { "privacy" => privacy.to_s, "source" => "docker", "network" => "disabled" }
        )
      rescue JSON::ParserError => error
        raise DockerError, "Image #{image} returned invalid inspection data: #{error.message}"
      ensure
        cleanup_container(container_name) if container_name
      end

      private

      def image_metadata(image)
        stdout, stderr, status = Open3.capture3("docker", "image", "inspect", image.to_s)
        raise DockerError, "Docker image #{image} is not available locally: #{Sanitizer.text(stderr.strip)}" unless status.success?

        details = JSON.parse(stdout).first || {}
        config = details["Config"] || {}
        {
          "image" => image.to_s,
          "image_id" => details["Id"],
          "architecture" => details["Architecture"],
          "os" => details["Os"],
          "working_directory" => config["WorkingDir"],
          "entrypoint" => Array(config["Entrypoint"]),
          "command" => Array(config["Cmd"]),
          "declared_environment_variables" => Array(config["Env"]).map { |entry| entry.split("=", 2).first }.sort
        }
      end

      def cleanup_container(name)
        Open3.capture3("docker", "rm", "--force", name.to_s)
      rescue Errno::ENOENT
        nil
      end
    end
  end
end
