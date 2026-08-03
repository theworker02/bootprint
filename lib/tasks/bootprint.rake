# frozen_string_literal: true

namespace :bootprint do
  desc "Capture a sanitized Rails runtime fingerprint"
  task capture: :environment do
    require "bootprint"
    path = ENV.fetch("BOOTPRINT_OUTPUT", "bootprint.lock")
    Bootprint.capture(label: Rails.env.to_s).write(path)
    puts "Captured Bootprint snapshot to #{path}"
  end

  desc "Run Bootprint Rails runtime diagnostics"
  task doctor: :environment do
    require "bootprint/cli"
    exit_code = Bootprint::CLI.start(["doctor"])
    abort "Bootprint doctor found blocking issues" unless exit_code.zero?
  end
end
