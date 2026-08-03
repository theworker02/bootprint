# frozen_string_literal: true

module Bootprint
  class Diff
    Change = Struct.new(:path, :local, :target, keyword_init: true) do
      def to_h
        { "path" => path, "local" => local, "target" => target }
      end
    end

    IGNORED_PATHS = %w[generated_at bootprint_version environment.name].freeze

    attr_reader :local, :target, :allowed_paths

    def initialize(local, target, allowed_paths: [])
      @local = local.is_a?(Snapshot) ? local.data : local
      @target = target.is_a?(Snapshot) ? target.data : target
      @allowed_paths = allowed_paths
    end

    def changes
      @changes ||= compare(local, target).reject { |change| ignored?(change.path) }
    end

    def allowed?(path)
      allowed_paths.any? { |pattern| File.fnmatch?(pattern, path, File::FNM_PATHNAME | File::FNM_EXTGLOB) }
    end

    private

    def compare(left, right, path = nil)
      if left.is_a?(Hash) && right.is_a?(Hash)
        (left.keys | right.keys).sort.flat_map do |key|
          compare(left[key], right[key], [path, key].compact.join("."))
        end
      elsif left != right
        [Change.new(path:, local: left, target: right)]
      else
        []
      end
    end

    def ignored?(path)
      IGNORED_PATHS.include?(path) || path == "capture" || path.start_with?("capture.") || allowed?(path)
    end
  end
end
