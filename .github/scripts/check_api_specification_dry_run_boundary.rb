#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

API_SPEC_DRY_RUN_REPO_ROOT = Pathname.new(File.expand_path("../..", __dir__))

API_SPEC_DRY_RUN_CHECKS = [
  {
    path: "docs/API仕様ページとdocs-src更新確認runbook.md",
    expected: [
      "`READ_ONLY_MAINTENANCE` が有効な間、API仕様ページは閲覧・状態確認・生成済み HTML の確認だけを続ける read-only 入口として扱います。",
      "API仕様ページ表示時の stale build enqueue",
      "`API仕様ページの build を再実行` からの手動 `retry_build`",
      "`site(/*site_path)` 表示時の stale build enqueue",
      "HTTP codeblock dry-run validation",
      "apply / import / 外部送信 / destructive action ではありません",
      "path-only の internal API sample",
      "外部 URL への request sample は dry-run 対象外"
    ]
  },
  {
    path: "app/controllers/admin/api_specifications_controller.rb",
    expected: [
      "@api_specification_build_enqueued = @api_specification_read_only_maintenance ? false : @api_specification_page.enqueue_build_if_stale!",
      "page.enqueue_build_if_stale! unless read_only_maintenance_mode?",
      "redirect_to admin_api_specification_path, alert: maintenance_retry_build_message",
      "dry_run: true",
      "destructive: false",
      "action_kind: \"admin_api_spec.http_codeblock_dry_run\"",
      "apply / import / 外部送信は実行していません",
      "外部 URL への request sample は dry-run 対象外です。",
      "path-only の internal API sample ではありません。"
    ]
  }
].freeze

api_spec_dry_run_errors = []

API_SPEC_DRY_RUN_CHECKS.each do |check|
  relative_path = check.fetch(:path)
  path = API_SPEC_DRY_RUN_REPO_ROOT.join(relative_path)

  unless path.file?
    api_spec_dry_run_errors << "#{relative_path}: missing file"
    next
  end

  content = path.read
  check.fetch(:expected).each do |expected_text|
    next if content.include?(expected_text)

    api_spec_dry_run_errors << "#{relative_path}: missing expected API specification dry-run boundary text: #{expected_text.inspect}"
  end
end

if api_spec_dry_run_errors.any?
  warn "API specification dry-run boundary guard failed:"
  api_spec_dry_run_errors.each { |error| warn "- #{error}" }
  exit 1
end

puts "API specification dry-run boundary guard passed."
