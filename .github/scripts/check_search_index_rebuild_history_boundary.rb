#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

REPO_ROOT = Pathname.new(File.expand_path("../..", __dir__))

CHECKS = [
  {
    path: "docs/search-index-rebuild履歴境界メモ.md",
    expected: [
      "current repo では、search index rebuild 専用の controller action、service、Rake task、GitHub Actions job はまだ current support として確認していません。",
      "Docusaurus site build は [site build 実行履歴保存境界メモ](./site-build実行履歴保存境界メモ.md)、Git連携 run は [Git連携 run 履歴保存境界メモ](./Git連携run履歴保存境界メモ.md) を正本にし、3 surface を同時に実装する候補として扱いません。",
      "site build artifact の成功可否とは別に、検索 index の再生成単位",
      "保存候補は次の allowlist に限定します。",
      "`source_repo` / `source_branch` / `source_commit_hash`: rebuild 入力の出自",
      "`manifest_path`: safe relative path の manifest 参照",
      "`indexed_document_count`: index 対象として処理した文書件数",
      "`indexed_record_count`: index entry の概算件数",
      "`error_summary`: 長い log 全文ではなく短い分類または先頭 summary",
      "index payload 全文",
      "raw document body / markdown body / HTML body",
      "private path / absolute path",
      "credential-like value / token / secret-like env",
      "CI log 全文",
      "query log / user input log 全文",
      "external search provider response 全文",
      "search index rebuild 実装や `GeneratedFileRun` への保存実装を追加せず、後続で具体 surface が決まったときの保存境界だけを固定します。",
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
