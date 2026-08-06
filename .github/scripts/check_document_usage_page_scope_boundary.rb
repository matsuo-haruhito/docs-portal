#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

REPO_ROOT = Pathname.new(File.expand_path("../..", __dir__))

CHECKS = [
  {
    path: "docs/runbooks/admin/文書利用状況運用runbook.md",
    expected: [
      "集計や CSV は案件横断には広がらず",
      "既読確認内訳",
      "CSV 本体、非同期 export、全件 export、案件横断レポート、KPI 定義変更として読まない",
      "table preferences で画面上の列を隠していても、CSV / JSON metadata の対象条件は変わらない"
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
    errors << "#{check.fetch(:path)}: missing: #{phrase.inspect}" unless content.include?(phrase)
  end
end

if errors.empty?
  puts "document usage page scope boundary check passed."
  exit 0
else
  warn "document usage page scope boundary check failed:"
  errors.each { |e| warn "  - #{e}" }
  exit 1
end
