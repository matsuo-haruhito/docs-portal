#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

REPO_ROOT = Pathname.new(File.expand_path("../..", __dir__))

# README の role 表に記載されている runbook リンクが実在することを確認する
README_PATH = "README.md"

ROLE_ENTRY_RUNBOOKS = [
  "docs/specs/ダッシュボードと文書ショートカット・確認依頼の使い分け.md",
  "docs/runbooks/viewer/利用者向けアクセス申請runbook.md",
  "docs/runbooks/viewer/利用者向け同意画面・同意履歴runbook.md",
  "docs/runbooks/viewer/利用者向け確認依頼runbook.md",
  "docs/runbooks/external/外部送付履歴運用runbook.md",
  "docs/runbooks/admin/company_master_admin会社・ユーザー管理runbook.md",
  "docs/runbooks/ops/管理ダッシュボード・モデルブラウザ運用runbook.md",
  "docs/runbooks/external/アクセス申請・同意管理・Webhook運用runbook.md",
  "docs/runbooks/import/案件・Git連携・文書セット初回セットアップrunbook.md"
].freeze

ROLE_PHRASES = [
  "external user",
  "internal user",
  "company_master_admin",
  "internal admin"
].freeze

errors = []

# README に 4 role が入口として列挙されていること
readme_content = REPO_ROOT.join(README_PATH).read
ROLE_PHRASES.each do |phrase|
  errors << "#{README_PATH}: missing role entry: #{phrase}" unless readme_content.include?(phrase)
end

# role 表からリンクされる runbook が実在すること
ROLE_ENTRY_RUNBOOKS.each do |path|
  unless REPO_ROOT.join(path).exist?
    errors << "Role entry runbook missing: #{path}"
  end
end

if errors.empty?
  puts "role entry drift boundary check passed."
  exit 0
else
  warn "role entry drift boundary check failed:"
  errors.each { |e| warn "  - #{e}" }
  exit 1
end
