# frozen_string_literal: true

require "json"

module Bootprint
  module Formatters
    class JSON
      def initialize(report) = @report = report
      def render = "#{::JSON.pretty_generate(@report.to_h)}\n"
    end
  end
end
