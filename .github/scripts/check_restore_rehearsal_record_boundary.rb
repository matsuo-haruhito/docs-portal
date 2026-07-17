#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

RESTORE_REHEARSAL_RECORD_REPO_ROOT = Pathname.new(File.expand_path("../..", __dir__))

RESTORE_REHEARSAL_RECORD_CHECKS = [
  {
    name: "backup restore procedure restore rehearsal template",
    path: "docs/バックアップ・リストア手順.md",
    expected: [
      "## 16. rehearsal 実施記録テンプレート",
      "restore rehearsal を実施したら、次回の復旧判断で追えるように 1 回分の結果を短く残します。",
      "実 backup artifact の中身、credential、secret、production path の詳細は貼らず",
      "`bin/verify_backup_artifacts`",
      "DB dump read:",
      "storage archive read:",
      "required storage prefixes:",
      "metadata / strict metadata:",
      "Markdown summary: 貼り付け先 / record ID",
      "DB restore:",
      "storage restore / 展開:",
      "再 build / 再 import:",
      "復元後 smoke:",
      "login:",
      "案件一覧:",
      "文書詳細:",
      "HTML 表示:",
      "添付 download:",
      "`storage_key` / `site_build_path` 整合:"
    ]
  },
  {
    name: "backup restore procedure NG return paths",
    path: "docs/バックアップ・リストア手順.md",
    expected: [
      "判定が `NG` または保留の場合は、restore を進めずに次のどこへ戻るかを記録します。",
      "artifact が読めない: 「保存先と命名」または artifact の再取得へ戻る",
      "DB dump / storage archive の片方だけ不整合: 「バックアップ対象」と取得手順を見直す",
      "staging smoke が落ちる: 「復元後の整合性確認」で落ちた項目と、再 restore / 再 build / 再 import のどれで切り分けるかを残す",
      "metadata warning を許容するか迷う: 同じ artifact で `--strict-metadata` を再実行するか、人間判断に戻す",
      "DB と `storage/` のどちらか片方だけ戻して復旧完了と見なさない",
      "restore 後は、少なくとも閲覧・ダウンロード・主要管理導線を目視確認する"
    ]
  }
].freeze

restore_rehearsal_record_errors = []

RESTORE_REHEARSAL_RECORD_CHECKS.each do |check|
  relative_path = check.fetch(:path)
  path = RESTORE_REHEARSAL_RECORD_REPO_ROOT.join(relative_path)

  unless path.file?
    restore_rehearsal_record_errors << "#{relative_path}: missing file for #{check.fetch(:name)}"
    next
  end

  content = path.read
  check.fetch(:expected).each do |expected_text|
    next if content.include?(expected_text)

    restore_rehearsal_record_errors << "#{relative_path}: missing restore rehearsal boundary signal: #{expected_text.inspect}"
  end
end

if restore_rehearsal_record_errors.any?
  warn "Restore rehearsal record boundary guard failed:"
  restore_rehearsal_record_errors.each { |error| warn "- #{error}" }
  exit 1
end

puts "Restore rehearsal record boundary guard passed."
