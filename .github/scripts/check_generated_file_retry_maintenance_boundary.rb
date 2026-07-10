#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

GENERATED_FILE_RETRY_MAINTENANCE_REPO_ROOT = Pathname.new(File.expand_path("../..", __dir__))

GENERATED_FILE_RETRY_MAINTENANCE_CHECKS = [
  {
    path: "app/controllers/admin/generated_file_events_controller.rb",
    expected: [
      "READ_ONLY_MAINTENANCE_ENV = \"READ_ONLY_MAINTENANCE\"",
      "def retry_dispatch",
      "redirect_to admin_generated_file_event_path(@generated_file_event.public_id, return_to: @return_to_path), alert: maintenance_retry_message",
      "def retry_failed",
      "redirect_to admin_generated_file_events_path(@filters), alert: maintenance_retry_message",
      "GeneratedFileEventDispatchJob.perform_later",
      "メンテナンス中のため生成ファイルイベントの再投入は停止しています。",
      "イベント一覧・詳細は閲覧できます。"
    ]
  },
  {
    path: "app/controllers/admin/generated_file_runs_controller.rb",
    expected: [
      "READ_ONLY_MAINTENANCE_ENV = \"READ_ONLY_MAINTENANCE\"",
      "def failure_alert_handoff",
      "read_only: true",
      "non_goals: %w[notification ack escalation retry]",
      "def retry_run",
      "redirect_to admin_generated_file_run_path(@generated_file_run.public_id, return_to: @return_to_path), alert: maintenance_retry_message",
      "def retry_failed",
      "redirect_to admin_generated_file_runs_path(@filters), alert: maintenance_retry_message",
      "GeneratedFileJob.perform_later",
      "メンテナンス中のため生成ファイルの再実行は停止しています。",
      "閲覧は継続できます。"
    ]
  },
  {
    path: "docs/生成ファイル再試行と定期ジョブ管理runbook.md",
    expected: [
      "`生成ファイルイベント`: `admin/generated_file_events`",
      "`生成ファイル実行履歴`: `admin/generated_file_runs`",
      "event は「生成依頼の入口」、run は「実際の生成処理」です。",
      "member の `retry_dispatch`",
      "collection の `retry_failed`",
      "member の `retry_run`",
      "current filter に一致する failed event のうち、古い順で今回 pending に戻る最大 100 件",
      "current filter に一致する failed run のうち、古い順で今回 enqueue 対象になる最大 100 件",
      "送信履歴とfailure handoffは閲覧できます",
      "一覧の `イベントID` と `詳細` は current の一覧 URL を `return_to` として detail へ渡します。",
      "一覧の `実行ID` と `詳細` は current の一覧 URL を `return_to` として detail へ渡します。"
    ]
  }
].freeze

generated_file_retry_maintenance_errors = []

GENERATED_FILE_RETRY_MAINTENANCE_CHECKS.each do |check|
  relative_path = check.fetch(:path)
  path = GENERATED_FILE_RETRY_MAINTENANCE_REPO_ROOT.join(relative_path)

  unless path.file?
    generated_file_retry_maintenance_errors << "#{relative_path}: missing file"
    next
  end

  content = path.read
  check.fetch(:expected).each do |expected_text|
    next if content.include?(expected_text)

    generated_file_retry_maintenance_errors << "#{relative_path}: missing generated file retry maintenance boundary text: #{expected_text.inspect}"
  end
end

if generated_file_retry_maintenance_errors.any?
  warn "Generated file retry maintenance boundary guard failed:"
  generated_file_retry_maintenance_errors.each { |error| warn "- #{error}" }
  exit 1
end

puts "Generated file retry maintenance boundary guard passed."
