# frozen_string_literal: true

module Bootprint
  module Rules
    module Registry
      module_function

      def add(rule)
        rules.reject! { |existing| existing.id == rule.id }
        rules << rule
        rule
      end

      def fetch(id) = rules.find { |rule| rule.id == id.to_s }
      def all = rules.dup
      def reset! = @rules = []
      def rules = @rules ||= []
    end
  end
end
