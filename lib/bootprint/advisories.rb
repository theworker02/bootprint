# frozen_string_literal: true

require "json"
require_relative "advisory_bundle_matcher"

module Bootprint
  # Matches snapshot gem versions against an offline advisory bundle.
  class Advisories
    DEFAULT_BUNDLE = File.expand_path("../../data/advisories/schema/empty.json", __dir__).freeze

    Advisory = Struct.new(:id, :gem, :title, :severity, :affected_versions, :url, :cve, keyword_init: true) do
      def to_h
        {
          "id" => id,
          "gem" => gem,
          "title" => title,
          "severity" => severity,
          "affected_versions" => affected_versions,
          "url" => url,
          "cve" => cve
        }.compact
      end
    end

    Match = Struct.new(:gem, :version, :advisory, keyword_init: true) do
      def to_h
        {
          "gem" => gem,
          "version" => version,
          "advisory" => advisory.to_h
        }
      end
    end

    attr_reader :bundle

    def self.load(path = DEFAULT_BUNDLE)
      parsed = JSON.parse(File.read(path, encoding: "UTF-8"))
      new(parsed, path:)
    rescue JSON::ParserError => error
      raise InvalidSnapshotError, "#{File.expand_path(path)} is not valid advisory JSON: #{error.message}"
    rescue Errno::ENOENT
      raise InvalidSnapshotError, "Advisory bundle not found: #{File.expand_path(path)}"
    end

    def self.match(snapshot, bundle: DEFAULT_BUNDLE)
      advisories(bundle).matches(snapshot)
    end

    def self.advisories(bundle = DEFAULT_BUNDLE)
      case bundle
      when Advisories then bundle
      when Hash then new(bundle)
      else load(bundle)
      end
    end

    def initialize(bundle, path: nil)
      @bundle = normalize_bundle(bundle)
      @path = path
    end

    def matches(snapshot)
      gems = extract_gems(snapshot)
      bundle_advisories.flat_map do |advisory|
        installed = gems[advisory.gem]
        next [] unless installed

        version = installed.is_a?(Hash) ? installed["version"] : installed
        next [] unless version && AdvisoryBundleMatcher.version_satisfies?(version, advisory.affected_versions)

        Match.new(gem: advisory.gem, version: version.to_s, advisory:)
      end
    end

    def clean?(snapshot) = matches(snapshot).empty?

    def to_h(snapshot = nil)
      matches = snapshot ? matches(snapshot) : []
      {
        "schema_version" => bundle.fetch("schema_version", 1),
        "bundle" => @path || "inline",
        "clean" => matches.empty?,
        "matches" => matches.map(&:to_h)
      }
    end

    private

    def bundle_advisories
      Array(bundle["advisories"]).map do |entry|
        Advisory.new(
          id: entry.fetch("id"),
          gem: entry.fetch("gem"),
          title: entry["title"] || entry.fetch("id"),
          severity: entry["severity"] || "unknown",
          affected_versions: AdvisoryBundleMatcher.normalize_versions(entry["affected_versions"] || entry["versions"]),
          url: entry["url"],
          cve: entry["cve"]
        )
      end
    end

    def extract_gems(snapshot)
      data = snapshot.is_a?(Snapshot) ? snapshot.data : snapshot
      gems = data.dig("environment", "dependencies", "gems") || {}
      gems.transform_keys(&:to_s)
    end

    def normalize_bundle(bundle)
      case bundle
      when Hash then bundle.transform_keys(&:to_s)
      when String then self.class.load(bundle).bundle
      else raise ArgumentError, "bundle must be a Hash or path"
      end
    end
  end
end
