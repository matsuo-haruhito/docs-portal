#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

REPO_ROOT = Pathname.new(File.expand_path("../..", __dir__))

CHECKS = [
  {
    path: "docs/runbooks/admin/文書利用状況運用runbook.md",
    expected: [
      "案件未選択時や invalid `project_id` では全件出力せず、画面へ戻して案件選択を促す",
      "CSV 本体、非同期 export、全件 export、案件横断レポート、KPI 定義変更として読まない",
      "table preferences で画面上の列を隠していても、CSV / JSON metadata の対象条件は変わらない",
      "棚卸し用ファイルとして読む"
    ]
  }
].freeze

errors = []

CHECKS.each do |check|
  file_path = REPO_ROOT.join(check.fetch(:path))

  unless file_path.exist?
    errors << "Missing file: #{check.fetch(:path)}"
    next
  end

  content = file_path.read

  check.fetch(:expected).each do |phrase|
    unless content.include?(phrase)
      errors << "#{check.fetch(:path)}: missing expected phrase: #{phrase.inspect}"
    end
  end
end

if errors.empty?
  puts "document usage CSV / metadata boundary check passed."
  exit 0
else
  warn "document usage CSV / metadata boundary check failed:"
  errors.each { |error| warn "  - #{error}" }
  exit 1
end
