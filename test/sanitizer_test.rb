# frozen_string_literal: true

require_relative "test_helper"

class SanitizerTest < Minitest::Test
  def test_replaces_application_and_home_paths
    root = File.expand_path(Dir.pwd)
    assert_includes Bootprint::Sanitizer.path(File.join(root, "config", "application.rb")), "<APP_ROOT>"
    assert_includes Bootprint::Sanitizer.path(File.join(Dir.home, "secret.txt")), "<HOME>"
  end

  def test_recursive_redaction_handles_secret_names_urls_jwts_and_private_keys
    input = {
      "API_TOKEN" => "actual-token",
      "database_url" => "postgres://user:password@example.test/db",
      "authorization" => "Bearer value",
      "nested" => { "value" => "eyJabcdefghijk.abcdefghijkl.abcdefghijkl" }
    }
    result = Bootprint::Sanitizer.recursive(input)

    assert_equal true, result.dig("API_TOKEN", "redacted")
    assert_equal "postgres://[REDACTED]@example.test/db", result["database_url"]
    assert_equal true, result.dig("authorization", "redacted")
    assert_equal Bootprint::Sanitizer::REDACTED, result.dig("nested", "value")
    refute_includes JSON.generate(result), "password"
  end

  def test_checksums_are_safe_listed_from_entropy_redaction
    checksum = "0123456789abcdef" * 4
    result = Bootprint::Sanitizer.recursive({ "lockfile_sha256" => checksum })
    assert_equal checksum, result["lockfile_sha256"]
  end

  def test_strict_privacy_anonymizes_hostnames
    assert_equal "<HOST>", Bootprint::Sanitizer.sanitize_value("internal.example.com", privacy: :strict)
  end

  def test_configurable_safe_list_preserves_a_nonsecret_named_field
    Bootprint.configuration.redaction_safe_list << "PUBLIC_TOKEN_NAME"
    result = Bootprint::Sanitizer.recursive({ "PUBLIC_TOKEN_NAME" => "documented-enum" })
    assert_equal "documented-enum", result["PUBLIC_TOKEN_NAME"]
  end
end
