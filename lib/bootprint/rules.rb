# frozen_string_literal: true

require_relative "rules/finding"
require_relative "rules/rule"
require_relative "rules/registry"

module Bootprint
  module Rules
    SEVERITY_ORDER = { info: 0, warning: 1, error: 2, critical: 3 }.freeze
    class << self
      def define(id, severity: nil, &block)
        rule = Rule.new(id, severity:)
        rule.instance_eval(&block)
        Registry.add(rule)
      end

      def register(name_or_rule)
        return Registry.add(name_or_rule) if name_or_rule.is_a?(Rule)

        require "bootprint/rules/#{name_or_rule}"
      rescue LoadError => error
        raise ConfigurationError, "Could not load Bootprint rules for #{name_or_rule}: #{error.message}"
      end

      def evaluate(source, target, policy: Policy.new, only: nil, minimum_severity: nil)
        categories = Array(only).map(&:to_sym)
        minimum = (minimum_severity || policy.minimum_severity).to_sym
        Registry.all.filter_map do |rule|
          next if !categories.empty? && !categories.include?(rule.category)

          finding = begin
            rule.evaluate(source, target, policy:)
          rescue StandardError => error
            Finding.new(
              rule_id: "#{rule.id}-evaluation-failure",
              title: "Diagnostic rule failed",
              category: :internal,
              severity: policy.plugin_strict? ? :error : :warning,
              summary: "Rule #{rule.id} could not evaluate this snapshot.",
              cause: Sanitizer.text("#{error.class}: #{error.message}"),
              impact: "This rule's diagnosis is incomplete; other rules continued.",
              evidence: { "rule_id" => rule.id },
              remediation: { "summary" => "Update the rule provider or Bootprint.", "commands" => [], "files" => [] },
              references: [], metadata: {}, suppressed: false
            )
          end
          next unless finding
          next if SEVERITY_ORDER.fetch(finding.severity) < SEVERITY_ORDER.fetch(minimum)

          finding
        end
      end
    end
  end
end

require_relative "rules/builtin"
Bootprint::Rules::Builtin.install
