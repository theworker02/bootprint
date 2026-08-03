# frozen_string_literal: true

require "set"

module Bootprint
  module InitializerProfiler
    NETWORK_METHODS = %i[connect connect_nonblock tcp start open].freeze

    module_function

    def install!
      return unless Bootprint.configuration.profile_boot
      return unless defined?(Rails::Initializable::Initializer)
      return if Rails::Initializable::Initializer.ancestors.include?(Instrumentation)

      ENV.singleton_class.prepend(EnvironmentProbe) unless ENV.singleton_class.ancestors.include?(EnvironmentProbe)
      Rails::Initializable::Initializer.prepend(Instrumentation)
    end

    def record_missing_environment(name)
      collector = Thread.current[:bootprint_missing_environment]
      collector << name.to_s if collector
    end

    def config_fingerprint
      return {} unless defined?(Rails) && Rails.respond_to?(:application) && Rails.application

      config = Rails.application.config
      %i[eager_load cache_classes time_zone cache_store session_store].to_h do |name|
        value = config.public_send(name) if config.respond_to?(name)
        [name.to_s, value.is_a?(Array) ? value.first.to_s : value.to_s]
      rescue StandardError
        [name.to_s, nil]
      end
    end

    module EnvironmentProbe
      def [](name)
        present = key?(name)
        value = super
        Bootprint::InitializerProfiler.record_missing_environment(name) unless present
        value
      end

      def fetch(name, *arguments, &)
        Bootprint::InitializerProfiler.record_missing_environment(name) unless key?(name)
        super
      end
    end

    module Instrumentation
      def run(*args)
        start_order = Bootprint::RailsState.initializers&.length.to_i + 1
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        constants_before = Object.constants.to_set
        config_before = Bootprint::InitializerProfiler.config_fingerprint
        missing_environment = []
        Thread.current[:bootprint_missing_environment] = missing_environment
        network_operation = false
        tracer = TracePoint.new(:call, :c_call) do |trace|
          owner = trace.defined_class.to_s
          network_operation = true if NETWORK_METHODS.include?(trace.method_id) && owner.match?(/Socket|Net::HTTP|OpenURI/)
        end
        tracer.enable
        exception = nil
        result = super
        result
      rescue Exception => error # rubocop:disable Lint/RescueException -- record boot failures, then re-raise
        exception = { "class" => error.class.name, "message" => Sanitizer.text(error.message) }
        raise
      ensure
        tracer&.disable
        duration = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1_000
        loaded = (Object.constants.to_set - constants_before).map(&:to_s).sort
        config_after = Bootprint::InitializerProfiler.config_fingerprint
        mutations = config_after.keys.reject { |key| config_before[key] == config_after[key] }
        Bootprint::RailsState.record_initializer(
          "name" => name.to_s,
          "start_order" => start_order,
          "completion_order" => Bootprint::RailsState.initializers&.length.to_i + 1,
          "duration_ms" => duration.round(3),
          "exception" => exception,
          "loaded_constants" => loaded.take(100),
          "missing_environment_variables" => missing_environment.uniq.sort,
          "network_operation_heuristic" => network_operation,
          "configuration_mutations" => mutations,
          "configuration_mutation_heuristic" => !mutations.empty?
        )
        Thread.current[:bootprint_missing_environment] = nil
      end
    end
  end
end
