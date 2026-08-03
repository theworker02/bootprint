# frozen_string_literal: true

module Bootprint
  module Collectors
    module Rails
      module_function

      def key = "rails"

      def capture
        return {} unless defined?(::Rails) && ::Rails.respond_to?(:application) && ::Rails.application

        application = ::Rails.application
        config = application.config
        {
          "version" => ::Rails.version,
          "environment" => ::Rails.env.to_s,
          "framework_defaults" => value(config, :loaded_config_version)&.to_s,
          "eager_load" => value(config, :eager_load),
          "cache_classes" => value(config, :cache_classes),
          "autoload_paths" => paths(value(config, :autoload_paths)),
          "eager_load_paths" => paths(value(config, :eager_load_paths)),
          "adapters" => adapters(config),
          "active_storage_service" => nested_value(config, :active_storage, :service)&.to_s,
          "action_cable_adapter" => action_cable_adapter,
          "mail_delivery_method" => nested_value(config, :action_mailer, :delivery_method)&.to_s,
          "time_zone" => value(config, :time_zone)&.to_s,
          "logging" => logging(config),
          "public_file_server_enabled" => nested_value(config, :public_file_server, :enabled),
          "assets_compile" => nested_value(config, :assets, :compile),
          "secret_key_base" => secret_metadata(application),
          "initializers" => sanitized_initializers
        }
      end

      def adapters(config)
        {
          "active_job" => nested_value(config, :active_job, :queue_adapter)&.to_s,
          "cache" => Array(value(config, :cache_store)).first&.to_s,
          "session" => value(config, :session_store)&.to_s,
          "database" => database_adapter
        }.compact
      end

      def database_adapter
        return unless defined?(ActiveRecord::Base)

        ActiveRecord::Base.connection_db_config.adapter
      rescue StandardError
        nil
      end

      def action_cable_adapter
        return unless defined?(ActionCable) && ActionCable.respond_to?(:server)

        ActionCable.server.config.cable.fetch("adapter", nil)
      rescue StandardError
        nil
      end

      def logging(config)
        logger = defined?(::Rails.logger) ? ::Rails.logger : nil
        { "level" => logger&.level, "class" => logger&.class&.name, "log_tags" => Array(value(config, :log_tags)).map(&:to_s) }
      end

      def secret_metadata(application)
        present = !application.secret_key_base.to_s.empty?
        source = ENV.key?("SECRET_KEY_BASE") ? "environment" : "credentials_or_configuration"
        { "present" => present, "source" => source, "redacted" => true }
      rescue StandardError
        { "present" => false, "source" => "unavailable", "redacted" => true }
      end

      def sanitized_initializers
        return [] unless defined?(Bootprint::RailsState)

        Array(Bootprint::RailsState.initializers).map do |initializer|
          initializer.merge("name" => Sanitizer.path(initializer["name"]))
        end
      end

      def paths(value)
        Array(value).map { |path| Sanitizer.path(path) }.sort
      end

      def value(object, method)
        object.public_send(method) if object.respond_to?(method)
      rescue StandardError
        nil
      end

      def nested_value(object, *methods)
        methods.reduce(object) { |current, method| current && value(current, method) }
      end
    end
  end
end
