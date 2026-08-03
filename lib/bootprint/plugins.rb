# frozen_string_literal: true

module Bootprint
  module Plugin
    API_VERSION = "1"

    module_function

    def api_version(value = nil)
      return API_VERSION unless value
      raise PluginError, "Plugin requires API #{value}; Bootprint provides #{API_VERSION}" unless value.to_s == API_VERSION

      API_VERSION
    end
  end

  module Plugins
    Definition = Struct.new(:name, :collector_class, :rules_module, :registration_error, keyword_init: true) do
      def collector(value = nil)
        self.collector_class = value if value
        collector_class
      end

      def rules(value = nil)
        self.rules_module = value if value
        rules_module
      end
    end

    class << self
      def register(name, &)
        definition = Definition.new(name: name.to_s)
        definition.instance_eval(&)
        install_rules(definition)
        registry.reject! { |plugin| plugin.name == definition.name }
        registry << definition
        definition
      rescue StandardError => error
        definition ||= Definition.new(name: name.to_s)
        definition.registration_error = Sanitizer.text("#{error.class}: #{error.message}")
        registry << definition
        definition
      end

      def capture(warnings:, strict: false)
        registry.each_with_object({}) do |plugin, result|
          if plugin.registration_error
            handle_failure(plugin, plugin.registration_error, warnings, strict)
            next
          end
          next unless plugin.collector_class

          begin
            value = plugin.collector_class.respond_to?(:capture) ? plugin.collector_class.capture : plugin.collector_class.new.capture
            result[plugin.name] = Sanitizer.recursive(Schema.stringify(value))
          rescue StandardError => error
            handle_failure(plugin, "#{error.class}: #{error.message}", warnings, strict)
          end
        end
      end

      def all = registry.dup
      def reset! = @registry = []

      private

      def registry = @registry ||= []

      def install_rules(definition)
        rules = definition.rules_module
        return unless rules

        if rules.respond_to?(:install)
          rules.install
        elsif rules.respond_to?(:register)
          rules.register
        else
          raise PluginError, "#{definition.name} rules must respond to install or register"
        end
      end

      def handle_failure(plugin, message, warnings, strict)
        sanitized = Sanitizer.text(message)
        raise PluginError, "Plugin #{plugin.name} failed: #{sanitized}" if strict

        warnings << { "plugin" => plugin.name, "message" => sanitized, "severity" => "warning" }
      end
    end
  end
end
