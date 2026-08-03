# frozen_string_literal: true

module Bootprint
  module RailsState
    class << self
      attr_reader :initializers

      def record_initializer(attributes)
        (@initializers ||= []) << Schema.stringify(attributes)
      end

      def reset!
        @initializers = []
      end
    end
  end
end
