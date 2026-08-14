# frozen_string_literal: true

require "test_helper"

class LocaleCaptureTest < Minitest::Test
  def test_operating_system_records_timezone_encoding_and_locale
    captured = Bootprint::Collectors::OperatingSystem.capture

    refute_nil captured["timezone"]["utc_offset"]
    refute_empty captured["encoding"]["external"]
    assert captured["locale"].key?("charmap")
  end

  def test_timezone_encoding_and_locale_drift_rules
    source = snapshot("environment" => { "operating_system" => os_payload("UTC", "UTF-8", "C") })
    target = snapshot("environment" => { "operating_system" => os_payload("EST", "Windows-1252", "en_US.UTF-8") })
    report = Bootprint::Diagnosis.new(source, target).run

    ids = report.findings.map(&:rule_id)
    assert_includes ids, "timezone-drift"
    assert_includes ids, "encoding-drift"
    assert_includes ids, "locale-drift"
  end

  def test_matching_locale_metadata_does_not_fire
    payload = os_payload("UTC", "UTF-8", "C")
    source = snapshot("environment" => { "operating_system" => payload })
    target = snapshot("environment" => { "operating_system" => payload.dup })
    report = Bootprint::Diagnosis.new(source, target).run

    ids = report.findings.map(&:rule_id)
    refute_includes ids, "timezone-drift"
    refute_includes ids, "encoding-drift"
    refute_includes ids, "locale-drift"
  end

  private

  def os_payload(zone, encoding, lang)
    {
      "name" => "linux",
      "cpu" => "x86_64",
      "capabilities" => { "make" => true },
      "ruby_headers" => { "present" => true },
      "timezone" => { "name" => zone, "utc_offset" => zone == "UTC" ? 0 : -18_000, "tz" => zone },
      "encoding" => { "external" => encoding, "internal" => nil },
      "locale" => { "lang" => lang, "lc_all" => nil, "charmap" => encoding }
    }
  end
end
