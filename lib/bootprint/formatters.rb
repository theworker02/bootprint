# frozen_string_literal: true

require_relative "formatters/human"
require_relative "formatters/json"
require_relative "formatters/sarif"
require_relative "formatters/markdown"

module Bootprint
  module Formatters
    module_function

    def render(format, report, color: false)
      case format.to_s
      when "human" then Human.new(report, color:).render
      when "json" then JSON.new(report).render
      when "sarif" then Sarif.new(report).render
      when "markdown" then Markdown.new(report).render
      else raise ConfigurationError, "Unknown format #{format.inspect}; use human, json, sarif, or markdown"
      end
    end
  end
end
