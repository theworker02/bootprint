# frozen_string_literal: true

# Backward-compatible facade for the 0.1 API.
module Bootprint
  class Analysis
    def initialize(source, target, allowed_paths: [])
      policy_data = allowed_paths.empty? ? {} : { "allow" => { "paths" => allowed_paths } }
      @diagnosis = Diagnosis.new(source, target, policy: Policy.new(nil, policy_data))
    end

    def results = @diagnosis.run.findings
  end
end
