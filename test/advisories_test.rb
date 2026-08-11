# frozen_string_literal: true

require_relative "test_helper"
require "bootprint/advisories"

class AdvisoriesTest < Minitest::Test
  def test_matches_vulnerable_gem_versions
    bundle = {
      "schema_version" => 1,
      "advisories" => [
        {
          "id" => "CVE-2024-TEST",
          "gem" => "rake",
          "title" => "Test advisory",
          "severity" => "high",
          "affected_versions" => ["< 13.2.0"]
        }
      ]
    }
    snapshot = snapshot("environment" => {
                          "dependencies" => {
                            "gems" => { "rake" => { "version" => "13.1.0" } }
                          }
                        })
    matches = Bootprint::Advisories.new(bundle).matches(snapshot)

    assert_equal 1, matches.length
    assert_equal "rake", matches.first.gem
    assert_equal "13.1.0", matches.first.version
    assert_equal "CVE-2024-TEST", matches.first.advisory.id
  end

  def test_clean_when_gem_version_is_not_affected
    bundle = {
      "schema_version" => 1,
      "advisories" => [
        { "id" => "CVE-2024-TEST", "gem" => "rake", "affected_versions" => ["< 13.0.0"] }
      ]
    }
    snapshot = snapshot("environment" => {
                          "dependencies" => {
                            "gems" => { "rake" => { "version" => "13.4.2" } }
                          }
                        })

    assert Bootprint::Advisories.new(bundle).clean?(snapshot)
    assert_empty Bootprint.advisories(snapshot, bundle:)
  end

  def test_empty_bundle_passes
    snapshot = snapshot("environment" => {
                          "dependencies" => {
                            "gems" => { "rake" => { "version" => "13.1.0" } }
                          }
                        })

    assert_empty Bootprint.advise(snapshot)
  end

  def test_bundle_matcher_supports_version_arrays
    assert Bootprint::AdvisoryBundleMatcher.version_satisfies?("1.2.3", ["< 2.0", ">= 1.0"])
    refute Bootprint::AdvisoryBundleMatcher.version_satisfies?("2.1.0", ["< 2.0"])
  end
end
