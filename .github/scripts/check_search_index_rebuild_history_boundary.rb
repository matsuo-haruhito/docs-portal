#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

REPO_ROOT = Pathname.new(File.expand_path("../..", __dir__))

CHECKS = [
  {
    path: "docs/search-index-rebuild履歴境界メモ.md",
    expected: [
      "current repo では、search index rebuild 専用の controller action、service、Rake task、GitHub Actions job はまだ current support として確認していません。",
      "site build artifact の成功可否とは別に、検索 index の再生成単位",
      "保存候補は次の allowlist に限定します。",
      "index payload 全文",
      "credential-like value / token / secret-like env",
      "search index rebuild 実装そのもの",
      "起動 surface 未確定のまま `GeneratedFileRun` への保存実装を追加しない"
    ]
  },
  {
    path: "docs/site-build実行履歴保存境界メモ.md",
    expected: [
      "search index rebuild の履歴は issue `#4586` の境界メモを正本にし、site build artifact 履歴とは別 surface として扱います。",
      "[search index rebuild 履歴境界メモ](./search-index-rebuild履歴境界メモ.md)"
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

    errors << "#{relative_path}: missing expected search index rebuild history boundary text: #{expected_text.inspect}"
  end
end

if errors.any?
  warn "Search index rebuild history boundary guard failed:"
  errors.each { |error| warn "- #{error}" }
  exit 1
end

puts "Search index rebuild history boundary guard passed."
