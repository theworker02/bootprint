# frozen_string_literal: true

require "digest"
require_relative "test_helper"

class SiteTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  SITE = File.join(ROOT, "site")

  def test_static_site_has_complete_local_references
    html = File.read(File.join(SITE, "index.html"))
    references = html.scan(/(?:href|src)="([^"]+)"/).flatten
    local_references = references.reject { |reference| reference.start_with?("http", "#") }

    local_references.each do |reference|
      path = reference.split(/[?#]/, 2).first
      assert_path_exists File.join(SITE, path), "missing site asset referenced by index.html: #{path}"
    end
  end

  def test_site_uses_official_distribution_links_and_unique_section_ids
    html = File.read(File.join(SITE, "index.html"))

    assert_includes html, "https://rubygems.org/gems/bootprint"
    assert_includes html, "https://open-vsx.org/extension/theworker02/bootprint"
    assert_includes html, "https://github.com/theworker02/bootprint"
    assert_includes html, "https://theworker02.github.io/bootprint/"

    ids = html.scan(/\sid="([^"]+)"/).flatten
    assert_equal ids.uniq, ids, "site section IDs must be unique"
  end

  def test_site_uses_the_canonical_logo_assets
    %w[bootprint-logo-512.png bootprint-logo-128.png bootprint-logo-64.png].each do |filename|
      source = File.join(ROOT, "assets", "branding", filename)
      published = File.join(SITE, "assets", filename)
      assert_equal Digest::SHA256.file(source).hexdigest, Digest::SHA256.file(published).hexdigest
    end
  end
end
