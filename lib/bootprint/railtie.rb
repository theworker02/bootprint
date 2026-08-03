# frozen_string_literal: true

require "rails/railtie"
require_relative "rails_state"
require_relative "initializer_profiler"

Bootprint::InitializerProfiler.install!

module Bootprint
  class Railtie < Rails::Railtie
    rake_tasks do
      load File.expand_path("../tasks/bootprint.rake", __dir__)
    end

    initializer "bootprint.observe_initializers", before: :load_config_initializers do
      next unless ENV["BOOTPRINT_INSPECT"] == "1" || Bootprint.configuration.profile_boot
      next if Bootprint.configuration.profile_boot

      Bootprint::RailsState.reset!
      ActiveSupport::Notifications.subscribe("load_config_initializer.railties") do |*args|
        event = ActiveSupport::Notifications::Event.new(*args)
        path = event.payload[:initializer]
        name = path.respond_to?(:to_path) ? path.to_path : path.to_s
        Bootprint::RailsState.record_initializer(
          "name" => name,
          "start_order" => Bootprint::RailsState.initializers.length + 1,
          "completion_order" => Bootprint::RailsState.initializers.length + 1,
          "duration_ms" => event.duration.round(3),
          "exception" => event.payload[:exception] && { "class" => event.payload[:exception].first },
          "loaded_constants" => [],
          "network_operation_heuristic" => false
        )
      end
    end
  end
end
