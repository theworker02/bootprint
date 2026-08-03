# frozen_string_literal: true

require_relative "test_helper"
require "bootprint/initializer_profiler"

class InitializerProfilerTest < Minitest::Test
  def test_missing_environment_probe_records_names_not_values
    names = []
    Thread.current[:bootprint_missing_environment] = names
    Bootprint::InitializerProfiler.record_missing_environment("PAYMENT_PRIVATE_KEY")
    assert_equal ["PAYMENT_PRIVATE_KEY"], names
  ensure
    Thread.current[:bootprint_missing_environment] = nil
  end
end
