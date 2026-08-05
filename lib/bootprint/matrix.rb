# frozen_string_literal: true

module Bootprint
  # Compares two or more snapshots to find consensus values and outlier environments.
  class Matrix
    Entry = Struct.new(:path, :values, :missing, :consensus, :outliers, keyword_init: true) do
      def consensus?
        !consensus.nil?
      end

      def to_h
        {
          "path" => path,
          "values" => values,
          "missing" => missing,
          "consensus" => consensus,
          "outliers" => outliers
        }
      end
    end

    attr_reader :snapshots

    def initialize(snapshots)
      @snapshots = snapshots.to_h.transform_keys(&:to_s).transform_values do |snapshot|
        snapshot.is_a?(Snapshot) ? snapshot.semantic_data : snapshot
      end.freeze
      raise ArgumentError, "matrix requires at least two named snapshots" if @snapshots.length < 2
    end

    def entries
      @entries ||= begin
        flattened = snapshots.transform_values { |data| flatten(data) }
        paths = flattened.values.flat_map(&:keys).uniq.sort.reject { |path| ignored?(path) }
        paths.filter_map do |path|
          values = {}
          missing = []
          flattened.each do |name, data|
            data.key?(path) ? values[name] = data[path] : missing << name
          end
          distinct = values.values.map { |value| canonical(value) }.uniq.length
          next if distinct <= 1 && missing.empty?

          consensus = consensus_value(values, snapshots.length)
          outliers = if consensus.nil?
                       snapshots.keys.sort
                     else
                       (values.filter_map { |name, value| name unless value == consensus } + missing).sort
                     end
          Entry.new(path:, values: values.sort.to_h, missing: missing.sort, consensus:, outliers:)
        end
      end
    end

    def clean?
      entries.empty?
    end

    def outlier_counts
      counts = snapshots.keys.to_h { |name| [name, 0] }
      entries.each { |entry| entry.outliers.each { |name| counts[name] += 1 } }
      counts.sort.to_h
    end

    def to_h
      {
        "schema" => 1,
        "environments" => snapshots.keys.sort,
        "clean" => clean?,
        "outlier_counts" => outlier_counts,
        "entries" => entries.map(&:to_h)
      }
    end

    private

    def flatten(value, prefix = nil, output = {})
      if value.is_a?(Hash)
        value.keys.sort_by(&:to_s).each do |original_key|
          key = original_key.to_s
          path = [prefix, key].compact.join(".")
          flatten(value.fetch(original_key), path, output)
        end
      else
        output[prefix] = value
      end
      output
    end

    def ignored?(path)
      Diff::IGNORED_PATHS.include?(path) || path == "capture" || path.start_with?("capture.")
    end

    def consensus_value(values, total)
      groups = values.values.group_by { |value| canonical(value) }
      winner = groups.max_by { |key, grouped| [grouped.length, key] }
      return nil unless winner && winner.last.length > total / 2

      winner.last.first
    end

    def canonical(value)
      Marshal.dump(value)
    rescue TypeError
      value.inspect
    end
  end
end
