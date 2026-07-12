#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

BACKUP_ARTIFACT_RELEASE_RECORD_REPO_ROOT = Pathname.new(File.expand_path("../..", __dir__))

BACKUP_ARTIFACT_RELEASE_RECORD_CHECKS = [
  {
    name: "Release record backup verification template",
    path: "docs/リリース・デプロイ・rollback手順.md",
    expected: [
      "- デプロイ前バックアップ:",
      "- `bin/verify_backup_artifacts`:",
      "- DB dump read:",
      "- storage archive read:",
      "- required storage prefixes:",
      "- metadata / strict metadata:",
      "- warnings:",
      "- overall result:",
      "- Markdown summary: 貼り付け先 / record ID"
    ]
  },
  {
    name: "Backup artifact read-only verifier docs",
    path: "docs/バックアップ・リストア手順.md",
    expected: [
      "read-only で最低限の健全性を確認する入口として `bin/verify_backup_artifacts` を使います。",
      "この command は restore を実行せず、`pg_restore --list` と archive listing だけを行います。",
      "release record へ検証結果を貼る場合は、通常の成功 / warning / failure 出力に加えて `--format markdown` を指定します。",
      "summary block には DB dump、storage archive、manifest、metadata、required storage prefix、warning、overall result が短くまとまります。",
      "release record に残す場合、Markdown summary の `overall result`、`warnings`、`metadata`、required storage prefix status が実行ログと矛盾していない",
      "metadata が不足している場合、通常は warning として表示します。",
      "命名 metadata の不足を検証失敗として扱いたい rehearsal では `--strict-metadata` を付けます。",
      "本番 DB への restore 実行",
      "本番 storage / object storage への書き込み"
    ]
  }
].freeze

backup_artifact_release_record_errors = []

BACKUP_ARTIFACT_RELEASE_RECORD_CHECKS.each do |check|
  relative_path = check.fetch(:path)
  path = BACKUP_ARTIFACT_RELEASE_RECORD_REPO_ROOT.join(relative_path)

  unless path.file?
    backup_artifact_release_record_errors << "#{relative_path}: missing file for #{check.fetch(:name)}"
    next
  end

  content = path.read
  check.fetch(:expected).each do |expected_text|
    next if content.include?(expected_text)

    backup_artifact_release_record_errors << "#{relative_path}: missing backup artifact release record signal: #{expected_text.inspect}"
  end
end

if backup_artifact_release_record_errors.any?
  warn "Backup artifact release record boundary guard failed:"
  backup_artifact_release_record_errors.each { |error| warn "- #{error}" }
  exit 1
end

puts "Backup artifact release record boundary guard passed."
