# frozen_string_literal: true

require "digest"
require "rubygems"

module Bootprint
  module Collectors
    module Gems
      module_function

      def key = "gems"

      def capture
        lockfile = File.file?("Gemfile.lock") ? "Gemfile.lock" : nil
        checksums = parse_checksums(lockfile)
        specs = resolved_specs
        lock_metadata = parse_lockfile(lockfile)

        {
          "lockfile_sha256" => lockfile && Digest::SHA256.file(lockfile).hexdigest,
          "platforms" => lock_metadata["platforms"],
          "ruby_version" => lock_metadata["ruby_version"],
          "bundled_with" => lock_metadata["bundled_with"],
          "git_sources" => lock_metadata["git_sources"],
          "path_sources" => lock_metadata["path_sources"],
          "resolved" => specs.sort_by(&:name).to_h do |spec|
            [spec.name, {
              "version" => spec.version.to_s,
              "platform" => spec.platform.to_s,
              "checksum" => checksums["#{spec.name} (#{spec.version})"],
              "native_extensions" => !spec.extensions.empty?,
              "missing_extensions" => spec.respond_to?(:missing_extensions?) && spec.missing_extensions?,
              "prerelease" => spec.version.prerelease?
            }.compact]
          end
        }
      end

      def resolved_specs
        return Bundler.load.specs.to_a if defined?(Bundler) && Bundler.respond_to?(:load)

        Gem.loaded_specs.values
      rescue StandardError
        Gem.loaded_specs.values
      end

      def parse_checksums(lockfile)
        return {} unless lockfile

        lines = File.readlines(lockfile, chomp: true)
        start = lines.index("CHECKSUMS")
        return {} unless start

        lines.drop(start + 1).take_while { |line| line.start_with?("  ") }.to_h do |line|
          name, checksum = line.strip.split(" sha256=", 2)
          [name, checksum]
        end
      end

      def parse_lockfile(lockfile)
        empty = { "platforms" => [], "git_sources" => [], "path_sources" => [] }
        return empty unless lockfile

        lines = File.readlines(lockfile, chomp: true)
        empty.merge(
          "platforms" => section_values(lines, "PLATFORMS"),
          "ruby_version" => single_section_value(lines, "RUBY VERSION")&.sub(/\Aruby\s+/, ""),
          "bundled_with" => single_section_value(lines, "BUNDLED WITH"),
          "git_sources" => source_values(lines, "GIT", "remote:"),
          "path_sources" => source_values(lines, "PATH", "remote:")
        )
      end

      def section_values(lines, heading)
        start = lines.index(heading)
        return [] unless start

        lines.drop(start + 1).take_while { |line| line.empty? || line.start_with?("  ") }
                             .filter_map { |line| line.strip unless line.strip.empty? }
      end

      def single_section_value(lines, heading)
        section_values(lines, heading).first
      end

      def source_values(lines, heading, prefix)
        indexes = lines.each_index.select { |index| lines[index] == heading }
        indexes.filter_map do |index|
          block = lines.drop(index + 1).take_while { |line| line.empty? || line.start_with?("  ") }
          remote = block.find { |line| line.strip.start_with?(prefix) }
          remote&.strip&.delete_prefix(prefix)&.strip
        end
      end
    end
  end
end
