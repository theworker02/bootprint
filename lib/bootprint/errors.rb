# frozen_string_literal: true

module Bootprint
  class Error < StandardError; end
  class InvalidSnapshotError < Error; end
  class ConfigurationError < Error; end
  class DockerError < Error; end
  class PluginError < Error; end
end
