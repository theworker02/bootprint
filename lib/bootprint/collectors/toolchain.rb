# frozen_string_literal: true

require "rubygems"

module Bootprint
  module Collectors
    module Toolchain
      module_function

      def key = "toolchain"

      def capture
        bundler_version = if defined?(Bundler::VERSION)
                            Bundler::VERSION
                          else
                            Gem.loaded_specs["bundler"]&.version&.to_s ||
                              Gem::Specification.find_all_by_name("bundler").map(&:version).max&.to_s
                          end
        { "rubygems_version" => Gem::VERSION, "bundler_version" => bundler_version }
      end
    end
  end
end
