#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

REPO_ROOT = Pathname.new(File.expand_path("../..", __dir__))

CSV_METADATA_DOC = "docs/CSV条件metadata_JSON運用メモ.md"

CHECKS = [
  {
    path: CSV_METADATA_DOC,
    expected: [
      "CSV 本体とは別の companion metadata",
      "CSV 本体へ metadata row、pre-header、footer を足すものではありません。",
      "HTML 表示設定: 画面上の列の見え方だけを変える補助。CSV 列や metadata の条件は変えない",
      "`report_type`: `access_logs`",
      "`row_limit`: 監査ログ CSV の最新 200 件上限",
      "`export_scope`: `current_filter_latest_rows`",
      "`page` は metadata link に含めません",
      "CSV / metadata は current filter の最新 200 件を説明します",
      "`report_type`: `document_usage_report`",
      "`export_scope`: `current_project_usage_report`",
      "案件未選択や invalid `project_id` の場合は、CSV と同じく全件 export へ広げず",
      "`report_type`: `document_sets`",
      "`export_scope`: `current_filters`",
      "文書セット行データ本体や `public_id` の一覧を返す API ではありません",
      "表示中 page の行数や、`文書セット一覧の表示設定` で見えている列数ではありません",
      "CSV header、CSV row、metadata 条件は変わりません",
      "scheduled report、background export、全件 export、retention policy、表示設定連動を current support として意味しません",
      "監査ログは「current filter の最新 200 件」、文書利用状況は「選択案件の current usage report」、文書セットは「current filter に一致する文書セット CSV」です"
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

    errors << "#{relative_path}: missing expected CSV metadata JSON boundary text: #{expected_text.inspect}"
  end
end

if errors.any?
  warn "CSV metadata JSON boundary guard failed:"
  errors.each { |error| warn "- #{error}" }
  exit 1
end

puts "CSV metadata JSON boundary guard passed."
