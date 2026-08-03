# frozen_string_literal: true

require "tmpdir"
require "rbconfig"

module Bootprint
  module Collectors
    module Filesystem
      module_function

      def key = "filesystem"

      def capture
        {
          "path_separator" => File::ALT_SEPARATOR || File::SEPARATOR,
          "case_sensitive" => case_sensitive?,
          "symlinks_supported" => File.respond_to?(:symlink),
          "temporary_directory" => directory_state(Dir.tmpdir),
          "required_directories" => {
            "current" => directory_state(Dir.pwd),
            "log" => directory_state(File.join(Dir.pwd, "log")),
            "tmp" => directory_state(File.join(Dir.pwd, "tmp"))
          }
        }
      end

      def directory_state(path)
        {
          "present" => File.directory?(path),
          "writable" => File.directory?(path) && File.writable?(path),
          "path" => Sanitizer.path(path)
        }
      end

      def case_sensitive?
        !Gem.win_platform? && !RbConfig::CONFIG["host_os"].to_s.include?("darwin")
      end
    end
  end
end
