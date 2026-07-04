#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

REPO_ROOT = Pathname.new(File.expand_path("../..", __dir__))

CHECKS = [
  {
    path: "app/renderers/docusaurus_site_renderer.rb",
    expected: [
      "def annotate_document_tables!(document, site_path)",
      "portal-doc-table-preference-wrapper",
      "data-docs-portal-table-wrapper",
      "portal-doc-preference-table",
      "data-docs-portal-document-version",
      "data-docs-portal-site-path",
      "data-docs-portal-table-index",
      "data-rails-table-preferences-table-key",
      "def stable_table_site_path(site_path)",
      "def stable_table_site_path_key(normalized_site_path)",
      "Base64.urlsafe_encode64(normalized_site_path.to_s, padding: false)",
      "def build_table_preference_key(version_for_key, normalized_site_path, table_index)"
    ]
  },
  {
    path: "spec/renderers/docusaurus_site_renderer_spec.rb",
    expected: [
      "adds stable table preference metadata to each standalone markdown table",
      "keeps mermaid and code blocks intact while annotating real tables",
      "adds stable table preference metadata in embedded mode without portal chrome",
      "expected_site_path_key = Base64.urlsafe_encode64(expected_site_path, padding: false)",
      "expected_table_key = \"document-version:#{version.public_id}:site-path:#{expected_site_path_key}:table:1\"",
      "portal-doc-table-preference-wrapper",
      "data-docs-portal-document-version",
      "data-docs-portal-site-path",
      "data-docs-portal-table-index",
      "data-rails-table-preferences-table-key"
    ]
  },
  {
    path: "docs/notes/docusaurus-table-preference-context-boundary.md",
    expected: [
      "通常表示と `embedded=1` 表示の両方で同じ metadata contract",
      "Stable table key は `DocumentVersion.public_id`、normalized site path、per-page table index",
      "通常表示と embedded 表示で同じ key を使います",
      "table caption / heading 由来の semantic key",
      "Markdown source position 由来の stable key",
      "column visibility、preset UI、full `rails-table-preferences` controller 接続"
    ]
  },
  {
    path: "docs/版詳細プレビュー・差分・添付確認runbook.md",
    expected: [
      "real HTML `<table>` ごとに stable key と wrapper metadata",
      "後続の table UX 拡張へつなぐ seam",
      "full `rails_table_preferences` UI",
      "保存済み幅調整",
      "issue `#475`",
      "column visibility、preset UI、full `rails_table_preferences` controller 接続"
    ]
  },
  {
    path: "ROADMAP.md",
    expected: [
      "`DocusaurusSiteRenderer` の table rewrite は current support",
      "portal-doc-table-preference-wrapper",
      "portal-doc-preference-table",
      "column visibility / preset UI / preference schema の最終判断は #475"
    ]
  }
].freeze

errors = []

CHECKS.each do |check|
  relative_path = check.fetch(:path)
  path = REPO_ROOT.join(relative_path)

  unless path.file?
    errors << "#{relative_path}: missing file"
    next
  end

  content = path.read
  check.fetch(:expected).each do |expected_text|
    next if content.include?(expected_text)

    errors << "#{relative_path}: missing expected Docusaurus table metadata boundary text: #{expected_text.inspect}"
  end
end

if errors.any?
  warn "Docusaurus table metadata boundary guard failed:"
  errors.each { |error| warn "- #{error}" }
  exit 1
end

puts "Docusaurus table metadata boundary guard passed."
