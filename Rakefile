# frozen_string_literal: true

require "rake/testtask"
require "rubocop/rake_task"
require "rubygems/package_task"
require "bundler/gem_tasks"

gemspec = Gem::Specification.load("bootprint.gemspec")
abort "Unable to load bootprint.gemspec" unless gemspec

Rake::TestTask.new do |task|
  task.libs << "test"
  task.pattern = "test/**/*_test.rb"
  task.warning = true
end

task default: :test

Gem::PackageTask.new(gemspec) do |package|
  package.need_tar = false
  package.need_zip = false
end

RuboCop::RakeTask.new(:lint) do |task|
  task.patterns = %w[lib test exe script Rakefile bootprint.gemspec]
end

desc "Run tests and lint checks"
task check: %i[test lint]

desc "Parse every committed GitHub workflow and configuration file"
task :workflow_check do
  ruby "script/validate_workflows"
end

desc "Run every local pre-release validation"
task release_check: %i[check workflow_check package]
