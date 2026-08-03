# frozen_string_literal: true

module Bootprint
  class Doctor
    def initialize(policy: Policy.new)
      @policy = policy
    end

    def run(snapshot = Snapshot.capture(label: "current"))
      Diagnosis.new(snapshot, snapshot, policy: @policy).run
    end
  end
end
