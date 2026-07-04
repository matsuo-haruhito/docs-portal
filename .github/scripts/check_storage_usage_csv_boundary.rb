#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

STORAGE_USAGE_CSV_REPO_ROOT = Pathname.new(File.expand_path("../..", __dir__))

STORAGE_USAGE_CSV_CHECKS = [
  {
    path: "config/routes.rb",
    expected: [
      "get \"storage_usage/document_files\", to: \"storage_usage#document_files\"",
      "get \"storage_usage/docs_sites\", to: \"storage_usage#docs_sites\"",
      "get \"storage_usage/imports\", to: \"storage_usage#imports\""
    ]
  },
  {
    path: "app/controllers/admin/storage_usage_controller.rb",
    expected: [
      "\"scope_status\"",
      "\"display_limit\"",
      "\"safe_relative_path\"",
      "\"read_only_note\"",
      "read-only handoff only; not a repair, delete, retention, billing, quota, or GCS policy decision",
      "read-only bounded handoff only; not a cleanup, delete, archive, retention, billing, quota, GCS policy, repair, or full export decision",
      "This does not prove cleanup, retention, billing, quota, repair, or external storage status."
    ]
  },
  {
    path: "docs/Storage使用量CSV-read-only-handoff境界メモ.md",
    expected: [
      "`admin/storage_usage/document_files`",
      "`admin/storage_usage/docs_sites`",
      "`admin/storage_usage/imports`",
      "`scope_status`",
      "`display_limit`",
      "`safe_relative_path`",
      "`read_only_note`",
      "read-only bounded handoff",
      "cleanup / delete / archive / retention / billing / quota / GCS policy / repair / full export decision ではありません",
      "`DocumentFile` 実体",
      "`Docs site build`",
      "`Import staging`"
    ]
  },
  {
    path: "docs/README.md",
    expected: [
      "Storage使用量CSV-read-only-handoff境界メモ",
      "Storage使用量 CSV の route、CSV header、read-only bounded handoff の非目標"
    ]
  }
].freeze

storage_usage_csv_errors = []

STORAGE_USAGE_CSV_CHECKS.each do |check|
  relative_path = check.fetch(:path)
  path = STORAGE_USAGE_CSV_REPO_ROOT.join(relative_path)

  unless path.file?
    storage_usage_csv_errors << "#{relative_path}: missing file"
    next
  end

  content = path.read
  check.fetch(:expected).each do |expected_text|
    next if content.include?(expected_text)

    storage_usage_csv_errors << "#{relative_path}: missing expected storage usage CSV boundary text: #{expected_text.inspect}"
  end
end

if storage_usage_csv_errors.any?
  warn "Storage usage CSV boundary guard failed:"
  storage_usage_csv_errors.each { |error| warn "- #{error}" }
  exit 1
end

puts "Storage usage CSV boundary guard passed."
