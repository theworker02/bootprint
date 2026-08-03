# frozen_string_literal: true

require "rails"
require "bootprint"

module BootprintExample
  class Application < Rails::Application
    config.load_defaults 7.1
    config.eager_load = ENV["RAILS_ENV"] == "production"
  end
end
