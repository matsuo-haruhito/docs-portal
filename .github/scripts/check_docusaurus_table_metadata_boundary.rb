#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

REPO_ROOT = Pathname.new(File.expand_path("../..", __dir__))

CHECKS = [
  {
    path: "app/renderers/docusaurus_site_renderer.rb",
    patterns: [
      /def annotate_document_tables!\(document, site_path\)/,
      /portal-doc-table-preference-wrapper/,
      /data-docs-portal-table-wrapper/,
      /portal-doc-preference-table/,
      /data-docs-portal-document-version/,
      /data-docs-portal-site-path/,
      /data-docs-portal-table-index/,
      /data-rails-table-preferences-table-key/,
      /def stable_table_site_path\(site_path\)/,
      /Base64\.urlsafe_encode64\(normalized_site_path\.to_s, padding: false\)/,
      /def build_table_preference_key\(version_for_key, normalized_site_path, table_index\)/
    ]
  },
  {
    path: "spec/renderers/docusaurus_site_renderer_spec.rb",
    patterns: [
      /adds stable table preference metadata to each standalone markdown table/,
      /adds stable table preference metadata in embedded mode without portal chrome/,
      /expected_site_path_key = Base64\.urlsafe_encode64/,
      /document-version:.*site-path:.*table:1/,
      /data-rails-table-preferences-table-key/
    ]
  },
  {
    path: "docs/notes/docusaurus-table-preference-context-boundary.md",
    patterns: [
      /通常表示と `embedded=1` 表示の両方で同じ metadata contract/,
      /DocumentVersion\.public_id.*normalized site path.*per-page table index/m,
      /通常表示と embedded 表示で同じ key/,
      /column visibility.*preset UI.*full `rails-table-preferences` controller/m,
      /具体的な不足.*新しい concrete Issue/m
    ]
  },
  {
    path: "docs/runbooks/viewer/版詳細プレビュー・差分・添付確認runbook.md",
    patterns: [
      /real HTML `<table>` ごとに stable key と wrapper metadata/,
      /full `rails_table_preferences` UI.*全面統合を意味しません/m,
      /current fallback.*具体的な不足.*新しい concrete Issue/m,
      /column visibility.*preset UI.*full `rails_table_preferences` controller/m
    ]
  },
  {
    path: ".kiro/steering/frontend-interaction-policy.md",
    patterns: [
      /Markdown preview table.*app 側 fallback/m,
      /full `rails_table_preferences` 統合を追う active Issue は現在ありません/m,
      /具体的な不足.*新しい concrete Issue/m
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
  check.fetch(:patterns).each do |pattern|
    next if content.match?(pattern)

    errors << "#{relative_path}: missing Docusaurus table metadata contract: #{pattern.inspect}"
  end
end

if errors.any?
  warn "Docusaurus table metadata boundary guard failed:"
  errors.each { |error| warn "- #{error}" }
  exit 1
end

puts "Docusaurus table metadata boundary guard passed."
