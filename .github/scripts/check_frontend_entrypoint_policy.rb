#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

REPO_ROOT = Pathname.new(File.expand_path("../..", __dir__))

DOC_CHECKS = [
  {
    path: "doc/frontend_interaction_policy.md",
    expected: [
      "Turbo のみ",
      "Stimulus",
      "application.js に直接 `querySelectorAll` とイベント登録を増やさない",
      "新しい UI では同じ形式を増やさない",
      "Tom Select 自体は避けない",
      "アプリ側で `new TomSelect(...)` を直接呼ぶ手書き初期化を増やすこと"
    ]
  },
  {
    path: "docs/README.md",
    expected: [
      "UI / JavaScript / Vite / Stimulus / 関連 gem を触る場合は",
      "../doc/frontend_interaction_policy.md"
    ]
  }
].freeze

ENTRYPOINT_CHECKS = [
  {
    path: "app/frontend/entrypoints/application.js",
    expected: [
      "Application.start()",
      "application.register(\"rails-table-preferences\", RailsTablePreferencesController)",
      "application.register(\"rails-fields-kit--tom-select\", TomSelectController)",
      "application.register(\"preview-table-resizer\", PreviewTableResizerController)",
      "application.register(\"markdown-preview-table-tools\", MarkdownPreviewTableToolsController)"
    ],
    forbidden: {
      "querySelectorAll" => "direct DOM querying belongs in a Stimulus controller or existing helper module, not the Vite entrypoint",
      "addEventListener" => "event wiring belongs in a Stimulus controller or existing helper module, not the Vite entrypoint",
      "new TomSelect" => "rails_fields_kit helpers should use the gem Stimulus controller instead of app-side direct Tom Select initialization",
      "function setup" => "new setupXxx-style entrypoint initializers are outside the frontend interaction policy",
      "const setup" => "new setupXxx-style entrypoint initializers are outside the frontend interaction policy"
    }
  }
].freeze

errors = []

(DOC_CHECKS + ENTRYPOINT_CHECKS).each do |check|
  relative_path = check.fetch(:path)
  path = REPO_ROOT.join(relative_path)

  unless path.file?
    errors << "#{relative_path}: missing file"
    next
  end

  content = path.read
  check.fetch(:expected, []).each do |expected_text|
    next if content.include?(expected_text)

    errors << "#{relative_path}: missing expected frontend policy signal: #{expected_text.inspect}"
  end

  check.fetch(:forbidden, {}).each do |forbidden_text, reason|
    next unless content.include?(forbidden_text)

    errors << "#{relative_path}: forbidden entrypoint pattern #{forbidden_text.inspect}: #{reason}"
  end
end

if errors.any?
  warn "Frontend entrypoint policy guard failed:"
  errors.each { |error| warn "- #{error}" }
  exit 1
end

puts "Frontend entrypoint policy guard passed."
