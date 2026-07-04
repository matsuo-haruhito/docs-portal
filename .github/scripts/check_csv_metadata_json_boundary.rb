#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

REPO_ROOT = Pathname.new(File.expand_path("../..", __dir__))

CSV_METADATA_DOC = "docs/CSV条件metadata_JSON運用メモ.md"
ACCESS_LOG_RUNBOOK = "docs/監査ログ運用runbook.md"
DOCUMENT_SETS_RUNBOOK = "docs/文書セット運用runbook.md"
ACCESS_LOG_CONTROLLER = "app/controllers/admin/access_logs_controller.rb"
DOCUMENT_SETS_CONTROLLER = "app/controllers/admin/document_sets_controller.rb"

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
  },
  {
    path: ACCESS_LOG_RUNBOOK,
    expected: [
      "`CSV条件metadata JSON` は最新 200 件 scope、`表示中ページmetadata JSON` は current page scope の条件・除外日付・上限・summary を確認する補助出力で、監査ログ行データそのものではない",
      "CSV は表示中 page ではなく current filter の最新 200 件から作られる",
      "`CSV条件metadata JSON`: `export_scope: current_filter_latest_rows` として、最新 200 件 export の条件、除外日付、row limit、summary を確認する",
      "`表示中ページmetadata JSON`: `export_scope: current_filter_current_page_rows` として、表示中 page export の条件、除外日付、row limit、`page`、summary を確認する",
      "metadata JSON は監査ログ行データそのものではありません。CSV を出す前に、どの条件・scope・page で出力するかを確認する補助出力として読みます。",
      "`監査ログ一覧の表示設定` は HTML 一覧で見たい列を切り替えるだけ",
      "CSV columns は監査用途の固定列で、表示設定で非表示にした列も CSV では固定列として出る"
    ]
  },
  {
    path: DOCUMENT_SETS_RUNBOOK,
    expected: [
      "`GET /admin/document_sets.json` は CSV 本体ではなく、現在の `検索` / `種別` / `公開範囲` 条件、件数、固定 CSV header、summary を確認する companion metadata JSON を返す。表示中 page や表示設定とは独立し、文書セット行データや `public_id` 一覧は返さない",
      "CSV header、CSV row、対象集合は変わらない。page 2 などを見ている状態で CSV 出力しても、出力対象はその page の行だけではなく、current filter に一致する全件である。",
      "metadata では `report_type: document_sets`、`export_scope: current_filters`、`filters`、`ignored_filters`、`row_count`、`csv_headers`、`summary` を確認できるが、CSV row や文書セットの `public_id` 一覧は返らない",
      "`文書セット一覧の表示設定` は、一覧で見たい列だけを残したいときに使う。ここで変わるのは table の見え方だけ",
      "文書セット CSV metadata JSON の `row_count`、`csv_headers`、`summary`、対象 filter",
      "表示設定で table の列を変えても metadata 条件や `csv_headers` は変わらない"
    ]
  },
  {
    path: ACCESS_LOG_CONTROLLER,
    expected: [
      "row_limit: ACCESS_LOGS_PER_PAGE",
      "export_scope: access_logs_export_scope",
      "metadata[:page] = page_param if current_page_csv_scope?",
      "current_page_csv_scope? ? \"current_filter_current_page_rows\" : \"current_filter_latest_rows\"",
      "CSV export は表示中ページではなく、現在の絞り込み条件に一致する最新\#{ACCESS_LOGS_PER_PAGE}件を出力します。"
    ]
  },
  {
    path: DOCUMENT_SETS_CONTROLLER,
    expected: [
      "report_type: \"document_sets\"",
      "export_scope: \"current_filters\"",
      "description: \"文書セットCSVの条件確認用metadataです。CSV本体の行データではありません。\"",
      "row_count: @document_sets_filtered_count",
      "csv_headers: CSV_HEADERS",
      "csv_columns_fixed: true"
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
