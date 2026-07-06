#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

IMPORT_DRY_RUN_HISTORY_REPO_ROOT = Pathname.new(File.expand_path("../..", __dir__))

IMPORT_DRY_RUN_HISTORY_CHECKS = [
  {
    name: "ZIP import dry-run history boundary memo",
    path: "docs/ZIPインポートdry-run履歴保存境界メモ.md",
    expected: [
      "保存してよい metadata 候補",
      "保存しない raw payload",
      "uploaded ZIP 本体",
      "展開済み file contents",
      "generated manifest 全文",
      "full tree payload / preview JSON 全文",
      "storage absolute path、runner workspace path、local private path",
      "credential、token、authorization header、secret-like value",
      "ZIP import dry-run は existing dry-run detail を current source of truth とする",
      "保存先や schema を流用済みとは扱いません"
    ]
  },
  {
    name: "ZIP import dry-run operations runbook",
    path: "docs/ZIPインポートdry-run運用runbook.md",
    expected: [
      "`ZIPインポート`: `admin/zip_imports/new`",
      "`ZIPインポートdry-run`: `admin/zip_imports/:id`",
      "`取り込み概要` card",
      "current controller では `analyzed` の dry-run だけが実行対象です。",
      "同じ ID を再実行するより `別のZIPをアップロード` から作り直す前提で見ます。",
      "warning / error の内部 JSON schema や importer 実装詳細は、この文書では再定義しません"
    ]
  },
  {
    name: "Git import run history boundary memo",
    path: "docs/Git連携run履歴保存境界メモ.md",
    expected: [
      "保存してよい metadata 候補",
      "保存しない raw payload",
      "summary_json の要約",
      "error_message のマスク済み preview",
      "raw clone log 全文",
      "credential、access token、authorization header、secret-like value",
      "repository contents の全文",
      "manifest 全文や import API payload 全文",
      "provider API response 全文",
      "既存 `GitImportRun` を current source of truth とする",
      "保存先や schema は流用済みと扱いません"
    ]
  },
  {
    name: "Git import run operations runbook",
    path: "docs/Git連携設定と同期失敗確認runbook.md",
    expected: [
      "`Git連携`: `admin/git_import_sources`",
      "`Git同期履歴`: `admin/git_import_runs`",
      "`summary_json のマスク済み詳細`",
      "`error_message` の safe preview",
      "完全な raw log ではありません",
      "保存値や同期処理をこの画面で再定義せず"
    ]
  }
].freeze

errors = []

IMPORT_DRY_RUN_HISTORY_CHECKS.each do |check|
  relative_path = check.fetch(:path)
  path = IMPORT_DRY_RUN_HISTORY_REPO_ROOT.join(relative_path)

  unless path.file?
    errors << "#{relative_path}: missing file for #{check.fetch(:name)}"
    next
  end

  content = path.read
  check.fetch(:expected).each do |expected_text|
    next if content.include?(expected_text)

    errors << "#{relative_path}: missing import dry-run history boundary signal: #{expected_text.inspect}"
  end
end

if errors.any?
  warn "Import dry-run history boundary guard failed:"
  errors.each { |error| warn "- #{error}" }
  exit 1
end

puts "Import dry-run history boundary guard passed."
