# frozen_string_literal: true

require "rubygems"

module Bootprint
  module AdvisoryBundleMatcher
    module_function

    def normalize_versions(value)
      case value
      when nil then []
      when Array then value.map(&:to_s)
      else [value.to_s]
      end
    end

    def version_satisfies?(version, constraints)
      constraints = normalize_versions(constraints)
      return true if constraints.empty?

      gem_version = Gem::Version.new(version.to_s)
      Gem::Requirement.new(constraints).satisfied_by?(gem_version)
    rescue ArgumentError
      false
    end

    def value_in_set?(value, allowed)
      case allowed
      when nil then true
      when Array then allowed.any? { |item| values_equal?(value, item) }
      else values_equal?(value, allowed)
      end
    end

    def values_equal?(left, right)
      left == right || left.to_s == right.to_s
    end
  end
end
