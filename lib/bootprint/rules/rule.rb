# frozen_string_literal: true

module Bootprint
  module Rules
    class Rule
      SEVERITIES = %i[info warning error critical].freeze
      PATH_ALIASES = {
        "ruby_version" => "runtime.ruby_version",
        "ruby_platform" => "runtime.platform",
        "bundler_version" => "dependencies.toolchain.bundler_version",
        "rubygems_version" => "dependencies.toolchain.rubygems_version",
        "openssl_version" => "native_libraries.openssl.runtime"
      }.freeze

      attr_reader :id, :human_name, :category_name, :severity_name, :metadata_value,
                  :reference_values, :source_location_value

      def initialize(id, severity: nil)
        @id = id.to_s
        @human_name = id.to_s.split("-").map(&:capitalize).join(" ")
        @category_name = :general
        @severity_name = (severity || :warning).to_sym
        @metadata_value = {}
        @reference_values = []
      end

      def name(value = nil)
        @human_name = value.to_s if value
        @human_name
      end

      def category(value = nil)
        @category_name = value.to_sym if value
        @category_name
      end

      def severity(value = nil)
        if value
          candidate = value.to_sym
          raise ConfigurationError, "Invalid severity #{value.inspect} for #{id}" unless SEVERITIES.include?(candidate)

          @severity_name = candidate
        end
        @severity_name
      end

      def detect(&block)
        @detector = block if block
        @detector
      end

      def explain(message = nil, &block)
        @explainer = block || ->(_source, _target, evidence = nil) { { "summary" => message.to_s, "evidence" => evidence } }
      end

      def remediate(summary = nil, commands: [], files: [], &block)
        @remediator = block || lambda do |_source, _target, _evidence = nil|
          { "summary" => summary.to_s, "commands" => commands, "files" => files }
        end
      end

      def metadata(value = nil, **pairs)
        @metadata_value.merge!(Schema.stringify(value || {}).merge(Schema.stringify(pairs)))
      end

      def references(*values)
        @reference_values.concat(values.flatten.map(&:to_s))
      end

      def source_location(path = nil, line: nil)
        @source_location_value = { "path" => path.to_s, "line" => line }.compact if path
        @source_location_value
      end

      # Compatibility with the 0.1 single-path rule API.
      def compare(path)
        @compare_path = PATH_ALIASES.fetch(path.to_s, path.to_s)
        detect { |source, target| dig(source, @compare_path) != dig(target, @compare_path) }
      end

      def condition(&block)
        @condition = block
      end

      def evaluate(source_snapshot, target_snapshot, policy:)
        source = environment(source_snapshot)
        target = environment(target_snapshot)
        evidence = detection_result(source, target, policy)
        return unless evidence

        explanation_arguments = if @compare_path
                                  [dig(source, @compare_path), dig(target, @compare_path), evidence]
                                else
                                  [source, target, evidence]
                                end
        details = Schema.stringify(invoke(@explainer, *explanation_arguments) || {})
        details = { "summary" => details.to_s, "evidence" => evidence } unless details.is_a?(Hash)
        remediation = Schema.stringify(invoke(@remediator, source, target, evidence) || {})
        effective_severity = policy.severity_for(id, severity_name)
        suppressed = policy.ignored?(id) || policy.disabled?(id)
        Finding.new(
          rule_id: id,
          title: details["title"] || human_name,
          category: category_name,
          severity: effective_severity,
          summary: details["summary"] || "#{human_name} was detected.",
          cause: details["cause"],
          impact: details["impact"],
          evidence: details["evidence"] || normalize_evidence(evidence),
          remediation: remediation,
          references: reference_values,
          metadata: metadata_value.merge("path" => @compare_path).compact,
          source_location: details["source_location"] || source_location_value,
          suppressed:,
          suppression_reason: suppressed ? policy.suppression_reason(id) : nil
        )
      end

      private

      def detection_result(source, target, policy)
        raise ConfigurationError, "Rule #{id} does not define detection logic" unless @detector

        if @compare_path && @condition
          local = dig(source, @compare_path)
          remote = dig(target, @compare_path)
          matched = @condition.call(local, remote, source, target)
          return matched && { "source" => local, "target" => remote }
        end
        result = invoke(@detector, source, target, policy)
        result == true ? {} : result
      end

      def environment(snapshot)
        snapshot.respond_to?(:environment) ? snapshot.environment : snapshot.fetch("environment", snapshot)
      end

      def invoke(callable, *arguments)
        return {} unless callable

        callable.call(*arguments.take(callable.arity.negative? ? arguments.length : callable.arity))
      end

      def normalize_evidence(value)
        value.is_a?(Hash) ? Schema.stringify(value) : { "detected" => value }
      end

      def dig(hash, path)
        path.split(".").reduce(hash) { |value, key| value.is_a?(Hash) ? value[key] : nil }
      end
    end
  end
end
