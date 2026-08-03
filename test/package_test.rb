# frozen_string_literal: true

require "test_helper"

class PackageTest < Minitest::Test
  REQUIRED_METADATA = %w[
    allowed_push_host
    bug_tracker_uri
    changelog_uri
    documentation_uri
    homepage_uri
    rubygems_mfa_required
    source_code_uri
  ].freeze

  REQUIRED_FILES = %w[
    README.md
    LICENSE
    CHANGELOG.md
    SECURITY.md
    exe/bootprint
    lib/bootprint.rb
    assets/branding/bootprint-logo-512.png
  ].freeze

  def setup
    @specification = Gem::Specification.load(File.expand_path("../bootprint.gemspec", __dir__))
  end

  def test_gemspec_is_valid_and_release_metadata_is_complete
    assert @specification.validate
    assert_equal Bootprint::VERSION, @specification.version.to_s
    assert_equal "MIT", @specification.license
    assert_equal "https://rubygems.org", @specification.metadata["allowed_push_host"]
    assert_equal "true", @specification.metadata["rubygems_mfa_required"]

    REQUIRED_METADATA.each do |key|
      refute_empty @specification.metadata[key], "missing gem metadata: #{key}"
    end
  end

  def test_release_files_are_present_and_package_paths_are_safe
    REQUIRED_FILES.each { |path| assert_includes @specification.files, path }
    @specification.files.each { |path| assert File.file?(path), "missing packaged file: #{path}" }

    forbidden = @specification.files.grep(%r{\A(?:\.git|pkg|test|tmp)/|(?:\A|/)bootprint\.lock\z|\.gem\z})
    assert_empty forbidden, "unsafe files in package: #{forbidden.join(', ')}"
  end

  def test_release_version_has_a_changelog_entry
    changelog = File.read(File.expand_path("../CHANGELOG.md", __dir__), encoding: "UTF-8")
    assert_match(/^## #{@specification.version} - \d{4}-\d{2}-\d{2}$/, changelog)
  end

  def test_gem_has_no_runtime_dependencies
    assert_empty @specification.runtime_dependencies
  end
end
