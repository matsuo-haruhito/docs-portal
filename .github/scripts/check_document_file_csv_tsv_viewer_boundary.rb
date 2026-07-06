#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

REPO_ROOT = Pathname.new(File.expand_path("../..", __dir__))

SPEC_PATH = "docs/specs/閲覧画面とUI.md"
RUNBOOK_PATH = "docs/版詳細プレビュー・差分・添付確認runbook.md"

CHECKS = [
  {
    path: SPEC_PATH,
    expected: [
      "## DocumentFile viewer registry",
      "viewer registry は、`DocumentFile` の content type、file extension、保持パス、外部同期 metadata、file size、viewer の利用可否を入力にして viewer を決める",
      "viewer registry は、ファイルを直接表示できない場合でも、理由と代替導線を利用者へ表示する",
      "viewer registry は、preview 成功・fallback・preview 不可・download only の状態を区別する",
      "viewer registry の判定は UI から直接分岐させず、サービスまたは presenter に集約する",
      "| CSV / TSV | table viewer | 大容量時は sample preview + download |",
      "CSV / TSV viewer は、Markdown table viewer UX と同様に検索・コピー・幅調整などを再利用できる設計にする"
    ]
  },
  {
    path: RUNBOOK_PATH,
    expected: [
      "## 9. 個別 `DocumentFile` preview の見方",
      "`DocumentFileViewerPlan` が判定した viewer kind に応じて inline preview または download に進みます",
      "current implementation で画面に出る確認観点だけを扱います",
      "種別ごとの方針正本は [閲覧画面とUI](./specs/閲覧画面とUI.md) の `DocumentFile viewer registry` を見ます",
      "| CSV / TSV | `CSV / TSV preview` | sample 行、表内検索、表示中行の CSV copy、先頭行 / 先頭列固定、列幅 reset を確認する。大きい file は先頭行だけの preview になり、全件確認は download に戻す |",
      "preview できない場合は、画面上の理由表示と download 導線を確認し、runbook 側で未実装 viewer を実装済み扱いしない",
      "`embedded=1` の file preview は版詳細の閲覧権限と scan 状態を満たす file だけを対象にする",
      "直接 download 導線では `DocumentFile` の download 権限を見て、inline preview と同じ前提にしない"
    ]
  }
].freeze

RUNBOOK_FORBIDDEN_TEXT = [
  "full spreadsheet viewer",
  "rails_table_preferences の列表示設定保存",
  "CSV import",
  "data mutation",
  "Markdown table toolbar の拡張",
  "DocumentFile viewer registry 全体の redesign"
].freeze

def read_file(relative_path)
  path = REPO_ROOT.join(relative_path)
  return [nil, "#{relative_path}: missing file"] unless path.file?

  [path.read, nil]
end

def section_between(content, start_marker, end_marker)
  start_index = content.index(start_marker)
  return nil unless start_index

  rest = content[start_index..]
  end_index = rest.index(end_marker)
  end_index ? rest[0...end_index] : rest
end

errors = []

CHECKS.each do |check|
  relative_path = check.fetch(:path)
  content, error = read_file(relative_path)
  if error
    errors << error
    next
  end

  check.fetch(:expected).each do |expected_text|
    next if content.include?(expected_text)

    errors << "#{relative_path}: missing expected CSV / TSV DocumentFile viewer boundary text: #{expected_text.inspect}"
  end
end

runbook, error = read_file(RUNBOOK_PATH)
if error
  errors << error
else
  document_file_preview_section = section_between(runbook, "## 9. 個別 `DocumentFile` preview の見方", "## 10.")

  if document_file_preview_section.nil?
    errors << "#{RUNBOOK_PATH}: missing individual DocumentFile preview section"
  else
    RUNBOOK_FORBIDDEN_TEXT.each do |forbidden_text|
      next unless document_file_preview_section.include?(forbidden_text)

      errors << "#{RUNBOOK_PATH}: current DocumentFile preview section should not present future CSV / TSV viewer work as current support: #{forbidden_text.inspect}"
    end
  end
end

if errors.any?
  warn "CSV / TSV DocumentFile viewer boundary guard failed:"
  errors.each { |message| warn "- #{message}" }
  exit 1
end

puts "CSV / TSV DocumentFile viewer boundary guard passed."
