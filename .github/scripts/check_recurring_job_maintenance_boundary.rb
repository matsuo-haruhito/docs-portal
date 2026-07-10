#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

RECURRING_JOB_MAINTENANCE_REPO_ROOT = Pathname.new(File.expand_path("../..", __dir__))

RECURRING_JOB_MAINTENANCE_CHECKS = [
  {
    path: "app/controllers/admin/recurring_job_schedules_controller.rb",
    expected: [
      "READ_ONLY_MAINTENANCE_ENV = \"READ_ONLY_MAINTENANCE\"",
      "def sync_definitions",
      "RecurringJobDispatcherJob.perform_now",
      "def request_run",
      "run_requested_at: Time.current",
      "RecurringJobDispatcherJob.perform_later",
      "メンテナンス中のため定期ジョブの定義同期・即時実行要求は停止しています。",
      "一覧・詳細・実行履歴は閲覧できます。"
    ]
  },
  {
    path: "docs/生成ファイル再試行と定期ジョブ管理runbook.md",
    expected: [
      "`定期ジョブ`: `admin/recurring_job_schedules`",
      "一覧には POST action の `定義を同期` があります。",
      "`定義を同期` は一覧を表示するだけでは実行されません。",
      "通常の `GET /admin/recurring_job_schedules`、filter 変更、reload、詳細から戻る操作、legacy な `sync_definitions=1` query は read-only として扱い",
      "`即時実行を要求` は `run_requested_at` を更新し、`RecurringJobDispatcherJob` を enqueue します。",
      "`定義を同期` が dispatcher 定義を schedule 行へ登録・更新する入口であるのに対し、`即時実行を要求` は既に存在する schedule 1 件の実行要求です。",
      "`実行履歴` は 50 件ずつ表示され",
      "実行履歴の page 移動では、`run_status`、`q`、`scheduled_from`、`scheduled_to`、`return_to`、`per_page` が維持されます。"
    ]
  },
  {
    path: "docs/本番運用・インフラ前提.md",
    expected: [
      "| 定期ジョブ操作 | `admin/recurring_job_schedules#sync_definitions` / `#request_run` | 要判断。",
      "`current` として扱うのは、controller guard、request spec、関連 runbook の current support が揃っている操作だけです。"
    ]
  }
].freeze

recurring_job_maintenance_errors = []

RECURRING_JOB_MAINTENANCE_CHECKS.each do |check|
  relative_path = check.fetch(:path)
  path = RECURRING_JOB_MAINTENANCE_REPO_ROOT.join(relative_path)

  unless path.file?
    recurring_job_maintenance_errors << "#{relative_path}: missing file"
    next
  end

  content = path.read
  check.fetch(:expected).each do |expected_text|
    next if content.include?(expected_text)

    recurring_job_maintenance_errors << "#{relative_path}: missing recurring job maintenance boundary text: #{expected_text.inspect}"
  end
end

if recurring_job_maintenance_errors.any?
  warn "Recurring job maintenance boundary guard failed:"
  recurring_job_maintenance_errors.each { |error| warn "- #{error}" }
  exit 1
end

puts "Recurring job maintenance boundary guard passed."
