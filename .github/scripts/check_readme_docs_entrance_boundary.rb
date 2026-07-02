#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

REPO_ROOT = Pathname.new(File.expand_path("../..", __dir__))

README_PATH = REPO_ROOT.join("README.md")
DOCS_README_PATH = REPO_ROOT.join("docs/README.md")

errors = []

def read_required_file(path, errors)
  unless path.file?
    errors << "#{path.relative_path_from(REPO_ROOT)}: missing file"
    return ""
  end

  path.read
end

def require_text(content, relative_path, expected_text, errors)
  return if content.include?(expected_text)

  errors << "#{relative_path}: missing expected README/docs entrance text: #{expected_text.inspect}"
end

def require_line_with(content, relative_path, label, required_texts, errors)
  line = content.lines.find { |candidate| candidate.include?(label) }

  unless line
    errors << "#{relative_path}: missing representative entrance line: #{label.inspect}"
    return
  end

  required_texts.each do |expected_text|
    next if line.include?(expected_text)

    errors << "#{relative_path}: #{label.inspect} line is missing entrance boundary text: #{expected_text.inspect}"
  end
end

readme = read_required_file(README_PATH, errors)
docs_readme = read_required_file(DOCS_README_PATH, errors)

unless readme.empty?
  require_text(readme, "README.md", "role 別に current support の入口だけを先に選びたい場合", errors)
  require_text(readme, "README.md", "Issue / PR 番号", errors)
  require_text(readme, "README.md", "番号だけで current action を判断せず", errors)

  require_line_with(
    readme,
    "README.md",
    "| external user |",
    [
      "ダッシュボードと文書ショートカット・確認依頼の使い分け",
      "利用者向けアクセス申請runbook",
      "利用者向け同意画面・同意履歴runbook",
      "`/dashboard` 起点"
    ],
    errors
  )
  require_line_with(
    readme,
    "README.md",
    "| internal user |",
    [
      "利用者向け確認依頼runbook",
      "外部送付履歴運用runbook",
      "社内向け導線"
    ],
    errors
  )
  require_line_with(
    readme,
    "README.md",
    "| company_master_admin |",
    [
      "company_master_admin会社・ユーザー管理runbook",
      "管理画面 nav 領域見出し運用メモ",
      "`会社` / `ユーザー` 管理に閉じる role 境界"
    ],
    errors
  )
  require_line_with(
    readme,
    "README.md",
    "| internal admin |",
    [
      "管理ダッシュボード・モデルブラウザ運用runbook",
      "アクセス申請・同意管理・Webhook運用runbook",
      "案件・Git連携・文書セット初回セットアップrunbook",
      "`/admin` 起点"
    ],
    errors
  )
end

unless docs_readme.empty?
  require_text(docs_readme, "docs/README.md", "Issue / PR 番号", errors)
  require_text(docs_readme, "docs/README.md", "番号だけを current action とせず", errors)

  require_line_with(
    docs_readme,
    "docs/README.md",
    "- 利用者画面 / viewer:",
    [
      "ダッシュボードと文書ショートカット・確認依頼の使い分け",
      "文書詳細・版詳細・ZIP・アクセス申請"
    ],
    errors
  )
  require_line_with(
    docs_readme,
    "docs/README.md",
    "- admin 運用:",
    [
      "管理ダッシュボード・モデルブラウザ運用runbook",
      "アクセス申請",
      "文書マスタ",
      "文書セット"
    ],
    errors
  )
  require_text(docs_readme, "docs/README.md", "company_master_admin会社・ユーザー管理runbook", errors)
  require_text(docs_readme, "docs/README.md", "案件・文書管理 role ではない境界", errors)
  require_text(docs_readme, "docs/README.md", "internal admin へ戻す判断", errors)
  require_text(docs_readme, "docs/README.md", "利用者向けアクセス申請runbook", errors)
  require_text(docs_readme, "docs/README.md", "利用者向け同意画面・同意履歴runbook", errors)
  require_text(docs_readme, "docs/README.md", "外部送付履歴運用runbook", errors)
end

if errors.any?
  warn "README/docs entrance boundary guard failed:"
  errors.each { |error| warn "- #{error}" }
  exit 1
end

puts "README/docs entrance boundary guard passed."
