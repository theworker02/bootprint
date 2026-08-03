# frozen_string_literal: true

require_relative "test_helper"

class PluginsTest < Minitest::Test
  GoodCollector = Class.new do
    def self.capture = { "queue_adapter" => "sidekiq" }
  end
  BrokenCollector = Class.new do
    def self.capture = raise("token=should-not-leak")
  end

  def test_plugin_api_contract_and_collection
    assert_equal "1", Bootprint::Plugin.api_version("1")
    Bootprint::Plugins.register "sidekiq" do
      collector PluginsTest::GoodCollector
    end
    captured = Bootprint::Snapshot.capture
    assert_equal "sidekiq", captured.environment.dig("plugins", "sidekiq", "queue_adapter")
  end

  def test_broken_plugin_does_not_block_core_capture
    Bootprint::Plugins.register "broken" do
      collector PluginsTest::BrokenCollector
    end
    captured = Bootprint::Snapshot.capture
    warning = captured.data.dig("capture", "warnings").find { |item| item["plugin"] == "broken" }
    refute_nil warning
    assert_equal 2, captured.data["schema_version"]
  end

  def test_strict_plugin_mode_raises
    Bootprint::Plugins.register "broken" do
      collector PluginsTest::BrokenCollector
    end
    Bootprint.configuration.plugin_strict = true
    assert_raises(Bootprint::PluginError) { Bootprint::Snapshot.capture }
  end
end
