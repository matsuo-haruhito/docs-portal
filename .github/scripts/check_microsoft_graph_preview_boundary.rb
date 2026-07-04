#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

REPO_ROOT = Pathname.new(File.expand_path("../..", __dir__))

CHECKS = [
  {
    path: "docs/Microsoft Graph接続管理runbook.md",
    expected: [
      "`previewで使用中`: current preview がこの接続を使います",
      "`有効だが未使用`: この行も有効ですが、別の有効接続が preview に使われています。legacy duplicate を整理するときの対象です",
      "`previewでは未使用`: 無効な接続、または preview の対象外の接続です",
      "current preview 正本は `preview_selected_ids_by_project` の実装どおり `同一案件の有効接続のうち最小 DB id` で暫定的に決まります",
      "`previewで使用中` は「もっとも妥当な設定を明示選択した結果」ではなく、旧データが残っている間だけの暫定表示です",
      "`#760` が landed したら、この節の暫定説明も current runtime に合わせて見直します",
      "preview の日常運用では、`previewで使用中` の行を 1 件だけ維持し、`有効だが未使用` を放置しない状態に戻します",
      "`要整理案件のみ`"
    ]
  },
  {
    path: "docs/preview接続と外部フォルダ同期の設定責務.md",
    expected: [
      "`MicrosoftGraphConnection` は preview 用接続",
      "`ExternalFolderSyncSource` は同期元設定",
      "Office ファイルの inline preview 用",
      "SharePoint / OneDrive の共有 URL から metadata を保存する first slice: 対応済み",
      "Graph -> Portal の dry-run / apply: 未対応"
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

    errors << "#{relative_path}: missing expected Microsoft Graph preview boundary text: #{expected_text.inspect}"
  end
end

if errors.any?
  warn "Microsoft Graph preview boundary guard failed:"
  errors.each { |error| warn "- #{error}" }
  exit 1
end

puts "Microsoft Graph preview boundary guard passed."
