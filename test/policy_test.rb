# frozen_string_literal: true

require_relative "test_helper"
require "bootprint/policy"

class PolicyTest < Minitest::Test
  def test_loads_complete_policy
    Dir.mktmpdir do |directory|
      path = File.join(directory, ".bootprint.yml")
      File.write(path, <<~YAML)
        version: 1
        mode: strict
        minimum_severity: warning
        fail_on: [error, critical]
        ignore: [ruby-patch-level-drift]
        expected_platforms: [x86_64-linux]
        allow:
          environment_variables: [OPTIONAL_ANALYTICS_KEY]
        rules:
          missing-environment-variable:
            severity: critical
        redaction:
          patterns: [CREDENTIAL]
          safe_list: [PUBLIC_TOKEN_NAME]
      YAML
      policy = Bootprint::Policy.load(path)
      assert policy.strict?
      assert policy.optional_environment_variable?("OPTIONAL_ANALYTICS_KEY")
      assert_equal :critical, policy.severity_for("missing-environment-variable", :error)
      assert_equal ["x86_64-linux"], policy.expected_platforms
      assert_equal ["PUBLIC_TOKEN_NAME"], policy.redaction_safe_list
    end
  end

  def test_semantic_error_contains_absolute_path_and_line
    Dir.mktmpdir do |directory|
      path = File.join(directory, ".bootprint.yml")
      File.write(path, "version: 1\nmode: dangerous\n")
      error = assert_raises(Bootprint::ConfigurationError) { Bootprint::Policy.load(path) }
      assert_includes error.message, File.expand_path(path)
      assert_includes error.message, ":2:"
    end
  end

  def test_syntax_error_contains_line
    Dir.mktmpdir do |directory|
      path = File.join(directory, ".bootprint.yml")
      File.write(path, "version: [\n")
      error = assert_raises(Bootprint::ConfigurationError) { Bootprint::Policy.load(path) }
      assert_match(/:\d+:\d+:/, error.message)
    end
  end
end
