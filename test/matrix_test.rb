# frozen_string_literal: true

require "test_helper"

class MatrixTest < Minitest::Test
  def test_finds_consensus_and_outlier
    local = snapshot("environment" => {"name" => "local", "runtime" => {"ruby_version" => "3.3.8"}})
    staging = snapshot("environment" => {"name" => "staging", "runtime" => {"ruby_version" => "3.4.2"}})
    production = snapshot("environment" => {"name" => "production", "runtime" => {"ruby_version" => "3.4.2"}})

    matrix = Bootprint.matrix(local:, staging:, production:)
    entry = matrix.entries.find { |item| item.path == "environment.runtime.ruby_version" }

    refute_nil entry
    assert_equal "3.4.2", entry.consensus
    assert_equal ["local"], entry.outliers
    assert_equal 1, matrix.outlier_counts.fetch("local")
    assert_equal 0, matrix.outlier_counts.fetch("staging")
  end

  def test_reports_missing_values
    matrix = Bootprint::Matrix.new(
      "one" => {"runtime" => {"jit" => "yjit"}},
      "two" => {"runtime" => {}},
      "three" => {"runtime" => {"jit" => "yjit"}}
    )

    entry = matrix.entries.fetch(0)
    assert_equal "runtime.jit", entry.path
    assert_equal "yjit", entry.consensus
    assert_equal ["two"], entry.missing
    assert_equal ["two"], entry.outliers
  end

  def test_requires_two_snapshots
    error = assert_raises(ArgumentError) { Bootprint::Matrix.new("local" => {}) }
    assert_match(/at least two/, error.message)
  end

  def test_clean_when_all_semantic_values_match
    left = snapshot("environment" => {"name" => "left"})
    right = snapshot("environment" => {"name" => "right"})
    assert Bootprint.matrix(left:, right:).clean?
  end
end
