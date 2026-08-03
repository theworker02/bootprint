# frozen_string_literal: true

require_relative "test_helper"
require "bootprint/formatters"

class ReportTest < Minitest::Test
  def setup
    super
    @report = Bootprint::Diagnosis.new(fixture_snapshot("macos-development"), fixture_snapshot("linux-ci")).run
  end

  def test_json_report_has_stable_required_fields
    report = JSON.parse(Bootprint::Formatters::JSON.new(@report).render)
    assert_equal 1, report["schema_version"]
    assert report.key?("source")
    assert report.key?("target")
    assert report.key?("execution")
    assert(report["findings"].all? { |finding| %w[rule_id severity evidence remediation suppressed].all? { |key| finding.key?(key) } })
  end

  def test_sarif_does_not_fabricate_missing_source_locations
    Dir.mktmpdir do |directory|
      Dir.chdir(directory) do
        sarif = JSON.parse(Bootprint::Formatters::Sarif.new(@report).render)
        results = sarif.dig("runs", 0, "results")
        refute(results.any? { |result| result.key?("locations") })
      end
    end
  end

  def test_sarif_maps_a_real_configuration_file
    Dir.mktmpdir do |directory|
      Dir.chdir(directory) do
        File.write(".ruby-version", "3.4.2\n")
        sarif = JSON.parse(Bootprint::Formatters::Sarif.new(@report).render)
        results = sarif.dig("runs", 0, "results")
        ruby_result = results.find { |result| result["ruleId"] == "ruby-version-drift" }
        assert_equal ".ruby-version", ruby_result.dig("locations", 0, "physicalLocation", "artifactLocation", "uri")
      end
    end
  end

  def test_no_color_is_emitted_for_redirected_output
    ENV["NO_COLOR"] = "1"
    output = Bootprint::Formatters::Human.new(@report, color: true).render
    refute_includes output, "\e["
  ensure
    ENV.delete("NO_COLOR")
  end
end
