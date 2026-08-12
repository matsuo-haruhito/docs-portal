#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

REPO_ROOT = Pathname.new(File.expand_path("../..", __dir__))

CHECKS = [
  {
    path: "docs/specs/文書ライフサイクルと公開.md",
    patterns: [
      /HTML view.*DocumentFile download.*ZIP download.*preview 実行/m,
      /codeblock dry-run.*action_type = dry_run.*target_type = dry_run/m,
      /filter 対象外.*target_type.*保存しない/m,
      /JS \/ CSS \/ image asset.*記録対象外/m,
      /last_login_at.*users.*別管理/m
    ]
  },
  {
    path: "docs/runbooks/admin/監査ログ運用runbook.md",
    patterns: [
      /target_type.*page.*file.*zip.*ai_context.*dry_run/m,
      /codeblock dry-run.*action_type=dry_run.*target_type=dry_run/m,
      /CSV条件metadata JSON.*監査ログ行データそのものではない/m,
      /監査ログ一覧の表示設定.*HTML 一覧/m,
      /CSV columns.*固定列/m,
      /監査ログ保存期間.*retention policy.*変えない/m
    ]
  },
  {
    path: "app/views/admin/access_logs/index.html.slim",
    patterns: [
      /table_key = :admin_access_logs/,
      /ColumnSettingsComponent\.new\(table_key: table_key/,
      /data-rails-table-preferences-column-key="accessed_at"/,
      /data-rails-table-preferences-column-key="action_type"/,
      /data-rails-table-preferences-column-key="target"/,
      /data-rails-table-preferences-column-key="user"/,
      /data-rails-table-preferences-column-key="company"/,
      /data-rails-table-preferences-column-key="project"/,
      /data-rails-table-preferences-column-key="document"/,
      /data-rails-table-preferences-column-key="document_version"/,
      /data-rails-table-preferences-column-key="ip_address"/
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

    errors << "#{relative_path}: missing AccessLog contract: #{pattern.inspect}"
  end
end

if errors.any?
  warn "AccessLog boundary guard failed:"
  errors.each { |error| warn "- #{error}" }
  exit 1
end

puts "AccessLog boundary guard passed."
