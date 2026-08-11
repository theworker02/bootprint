# frozen_string_literal: true

require_relative "bootprint/version"
require_relative "bootprint/errors"
require_relative "bootprint/configuration"
require_relative "bootprint/sanitizer"
require_relative "bootprint/schema"
require_relative "bootprint/plugins"
require_relative "bootprint/snapshot"
require_relative "bootprint/diff"
require_relative "bootprint/matrix"
require_relative "bootprint/advisories"
require_relative "bootprint/doctor"
require_relative "bootprint/policy"

module Bootprint
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def rule(name, severity: nil, &block)
      Rules.define(name, severity: severity, &block)
    end

    def capture(label: nil, **options)
      Snapshot.capture(label:, **options)
    end

    # Compares named snapshots and identifies consensus values and outliers.
    def matrix(snapshots)
      Matrix.new(snapshots)
    end

    def advisories(snapshot, bundle: Advisories::DEFAULT_BUNDLE)
      Advisories.advisories(bundle).matches(snapshot)
    end

    def advise(snapshot, bundle: Advisories::DEFAULT_BUNDLE)
      advisories(snapshot, bundle:)
    end
  end
end

require_relative "bootprint/rules"
require_relative "bootprint/diagnosis"
require_relative "bootprint/analysis"

require_relative "bootprint/railtie" if defined?(Rails::Railtie)
