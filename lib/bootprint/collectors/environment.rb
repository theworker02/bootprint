# frozen_string_literal: true

module Bootprint
  module Collectors
    module Environment
      module_function

      def key = "environment"

      def capture
        names = ENV.keys.select { |name| Bootprint.configuration.capture_environment?(name) }
        names |= Bootprint.configuration.required_environment_names
        names |= Bootprint.configuration.optional_environment_names
        {
          "variables" => names.sort.to_h { |name| [name, ENV.key?(name)] },
          "redaction" => "Names and presence only; values are never captured."
        }
      end
    end
  end
end
