#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

REPO_ROOT = Pathname.new(File.expand_path("../..", __dir__))

SPEC_PATH = "docs/specs/閲覧画面とUI.md"
RUNBOOK_PATH = "docs/版詳細プレビュー・差分・添付確認runbook.md"

CHECKS = [
  {
    path: SPEC_PATH,
    expected: [
      "## Codeblock actions",
      "codeblock actions は、コピーなどの即時操作と、dry-run / 検証などのサーバー連携操作を区別する",
      "サーバー連携操作は、権限判定、CSRF対策、実行前確認、結果表示、access log を必須とする",
      "| `yaml` / `yml` | YAMLコピー / validation |",
      "| `bash` / `sh` | コマンドコピー |",
      "| `http` | request sample コピー / dry-run |",
      "| unknown | copy only |",
      "admin は API仕様ページの codeblock action を dry-run で検証できる"
    ]
  },
  {
    path: RUNBOOK_PATH,
    expected: [
      "### Markdown codeblock toolbar の使い方",
      "language badge: `json` など、codeblock class から読み取れる言語を確認する。判定できない場合は `code` と表示される",
      "`コピー`: 表示中の codeblock 本文を clipboard にコピーする",
      "`JSON整形コピー`: `json` と判定された codeblock だけに出る",
      "`JSON検証`: `json` と判定された codeblock だけに出る",
      "`機密注意`: `secret`、`token`、`password`、`authorization`、`api key` などの keyword を含む codeblock で出る補助 cue",
      "行番号: 複数行の codeblock では行番号から `#codeblock-N-LM` の deep link を作れる",
      "正式な承認 workflow や監査ログとしては扱わない"
    ]
  }
].freeze

FORBIDDEN_CURRENT_TOOLBAR_TEXT = [
  "YAMLコピー",
  "YAML検証",
  "コマンドコピー",
  "request sample コピー",
  "dry-run",
  "server-side"
].freeze

def read_file(relative_path)
  path = REPO_ROOT.join(relative_path)
  return [nil, "#{relative_path}: missing file"] unless path.file?

  [path.read, nil]
end

def section_between(content, start_marker, end_marker)
  start_index = content.index(start_marker)
  return nil unless start_index

  rest = content[start_index..]
  end_index = rest.index(end_marker)
  end_index ? rest[0...end_index] : rest
end

errors = []

CHECKS.each do |check|
  relative_path = check.fetch(:path)
  content, error = read_file(relative_path)
  if error
    errors << error
    next
  end

  check.fetch(:expected).each do |expected_text|
    next if content.include?(expected_text)

    errors << "#{relative_path}: missing expected markdown codeblock toolbar boundary text: #{expected_text.inspect}"
  end
end

runbook, error = read_file(RUNBOOK_PATH)
if error
  errors << error
else
  toolbar_section = section_between(runbook, "### Markdown codeblock toolbar の使い方", "## 5.")

  if toolbar_section.nil?
    errors << "#{RUNBOOK_PATH}: missing Markdown codeblock toolbar section"
  else
    FORBIDDEN_CURRENT_TOOLBAR_TEXT.each do |forbidden_text|
      next unless toolbar_section.include?(forbidden_text)

      errors << "#{RUNBOOK_PATH}: current Markdown codeblock toolbar section should not present proposal-only action as current support: #{forbidden_text.inspect}"
    end
  end
end

if errors.any?
  warn "Markdown codeblock toolbar boundary guard failed:"
  errors.each { |message| warn "- #{message}" }
  exit 1
end

puts "Markdown codeblock toolbar boundary guard passed."
