#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

REPO_ROOT = Pathname.new(File.expand_path("../..", __dir__))

CHECKS = [
  {
    path: "docs/runbooks/admin/文書一括編集dry-run運用runbook.md",
    expected: [
      "事前確認",
      "dry-run 作成、bulk edit 実行、archive / restore / delete には進まず",
      "選択状態JSONを確認",
      "dry-runを作らずJSONだけを確認します"
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
  puts "bulk edit dry-run boundary check passed."
  exit 0
else
  warn "bulk edit dry-run boundary check failed:"
  errors.each { |e| warn "  - #{e}" }
  exit 1
end
