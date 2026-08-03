# frozen_string_literal: true

require_relative "test_helper"

class PerformanceTest < Minitest::Test
  def test_standard_snapshot_is_under_one_second
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    Bootprint::Snapshot.capture
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    assert_operator elapsed, :<, 1.0
  end

  def test_ordinary_diagnosis_is_under_half_a_second
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    Bootprint::Diagnosis.new(fixture_snapshot("macos-development"), fixture_snapshot("linux-ci")).run
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    assert_operator elapsed, :<, 0.5
  end
end
