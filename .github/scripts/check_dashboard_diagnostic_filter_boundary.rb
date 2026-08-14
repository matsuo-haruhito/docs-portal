#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

REPO_ROOT = Pathname.new(File.expand_path("../..", __dir__))

CHECKS = [
  {
    path: "docs/runbooks/ops/管理ダッシュボード・モデルブラウザ運用runbook.md",
    expected: [
      "アプリ設定診断",
      "日常運用で使い分けるための入口",
      "status filter",
      "category filter",
      "新しい診断 rule を足すものではない"
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
  puts "dashboard diagnostic filter boundary check passed."
  exit 0
else
  warn "dashboard diagnostic filter boundary check failed:"
  errors.each { |e| warn "  - #{e}" }
  exit 1
end
