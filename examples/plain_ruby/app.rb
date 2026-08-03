# frozen_string_literal: true

require "bootprint"

Bootprint.configure do |config|
  config.required_environment_names << "DATABASE_URL"
end

Bootprint.capture(label: "plain-ruby").write("bootprint.lock")
puts "Captured plain Ruby environment without reading DATABASE_URL."
