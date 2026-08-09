#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

REPO_ROOT = Pathname.new(File.expand_path("../..", __dir__))

CHECKS = [
  {
    path: "docs/specs/Microsoft Graph接続とOffice preview.md",
    patterns: [
      /enabled.*preview_selected/m,
      /preview_selected.*案件ごとに最大 1 件/m,
      /無効化.*選択.*解除/m,
      /明示選択がない旧データ.*最小 DB id.*互換 fallback/m
    ]
  },
  {
    path: "docs/runbooks/external/Microsoft Graph接続管理runbook.md",
    patterns: [
      /`previewで使用中`.*preview_selected/m,
      /`有効だが未使用`.*legacy duplicate/m,
      /`previewでは未使用`.*無効/m,
      /preview_selected.*案件ごとに最大 1 件/m,
      /明示選択がない旧データ.*最小 DB id.*互換 fallback/m,
      /`要整理案件のみ`/
    ]
  },
  {
    path: "docs/specs/preview接続と外部フォルダ同期の設定責務.md",
    patterns: [
      /`MicrosoftGraphConnection` は preview 用接続/,
      /`ExternalFolderSyncSource` は同期元設定/,
      /preview_selected.*案件ごと/m,
      /Graph -> Portal の dry-run \/ apply: 未対応/
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

    errors << "#{relative_path}: missing Microsoft Graph preview contract: #{pattern.inspect}"
  end
end

if errors.any?
  warn "Microsoft Graph preview boundary guard failed:"
  errors.each { |error| warn "- #{error}" }
  exit 1
end

puts "Microsoft Graph preview boundary guard passed."
