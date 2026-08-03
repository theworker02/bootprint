# frozen_string_literal: true

require_relative "lib/bootprint/version"

Gem::Specification.new do |spec|
  spec.name = "bootprint"
  spec.version = Bootprint::VERSION
  spec.authors = ["Magnexis"]
  spec.email = ["hello@magnexis.com"]
  spec.summary = "Diagnose runtime-environment drift in Ruby applications"
  spec.description = [
    "Bootprint captures sanitized Ruby and Rails runtime fingerprints,",
    "diagnoses dangerous environment drift, and provides policy-aware",
    "remediation for CI, Docker, staging, and production."
  ].join(" ")
  spec.homepage = "https://github.com/magnexis/bootprint"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"
  spec.required_rubygems_version = ">= 3.3.0"

  spec.files = Dir[
    "{lib,exe}/**/*",
    "assets/branding/{README.md,bootprint-logo.png,bootprint-logo-512.png,bootprint-logo-128.png,bootprint-logo-64.png}",
    "docs/**/*.md",
    "README.md",
    "ARCHITECTURE.md",
    "SECURITY.md",
    "CONTRIBUTING.md",
    "CODE_OF_CONDUCT.md",
    "ROADMAP.md",
    "RELEASE.md",
    "LICENSE*",
    "CHANGELOG.md",
    ".bootprint.yml.example"
  ].sort
  spec.bindir = "exe"
  spec.executables = ["bootprint"]
  spec.require_paths = ["lib"]

  spec.metadata = {
    "source_code_uri" => "#{spec.homepage}/tree/main",
    "homepage_uri" => spec.homepage,
    "documentation_uri" => "#{spec.homepage}/tree/main/docs",
    "changelog_uri" => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "bug_tracker_uri" => "#{spec.homepage}/issues",
    "funding_uri" => "https://github.com/sponsors/theworker02",
    "allowed_push_host" => "https://rubygems.org",
    "rubygems_mfa_required" => "true"
  }
end
