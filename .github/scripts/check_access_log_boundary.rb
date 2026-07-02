#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

REPO_ROOT = Pathname.new(File.expand_path("../..", __dir__))

CHECKS = [
  {
    path: "README.md",
    expected: [
      "AccessLog",
      "記録対象",
      "記録しない対象",
      "last_login_at は users 側で管理"
    ]
  },
  {
    path: "docs/README.md",
    expected: [
      "AccessLog",
      "記録対象",
      "記録しない対象",
      "last_login_at は users 側で管理"
    ]
  },
  {
    path: "docs/specs/文書ライフサイクルと公開.md",
    expected: [
      "HTML view、DocumentFile download、ZIP download、preview 実行などの主要操作を監査ログに残す",
      "JS / CSS / image asset は通常の閲覧履歴としては記録対象外にする",
      "last_login_at は `users` 側で別管理する"
    ]
  },
  {
    path: "docs/監査ログ運用runbook.md",
    expected: [
      "`action_type` は `view` `download` などの代表操作を絞り込む",
      "`target_type` は current UI では `page` `file` `zip` `ai_context` を扱う",
      "HTML 本文の閲覧、添付ファイル配布、ZIP 配布、AI context export の利用証跡を切り分けたいときに使う",
      "`CSV条件metadata JSON` は最新 200 件 scope、`表示中ページmetadata JSON` は current page scope の条件・除外日付・上限・summary を確認する補助出力で、監査ログ行データそのものではない",
      "metadata JSON は監査ログ行データそのものではありません",
      "`監査ログ一覧の表示設定` は HTML 一覧で見たい列を切り替えるだけ",
      "CSV columns は監査用途の固定列で、表示設定で非表示にした列も CSV では固定列として出る",
      "監査ログ保存期間や retention policy は変えない",
      "`q` は `target_name` / `ip_address` の補助検索であり、user_agent 検索や全文検索 index ではない"
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

    errors << "#{relative_path}: missing expected AccessLog boundary text: #{expected_text.inspect}"
  end
end

if errors.any?
  warn "AccessLog boundary guard failed:"
  errors.each { |error| warn "- #{error}" }
  exit 1
end

puts "AccessLog boundary guard passed."
