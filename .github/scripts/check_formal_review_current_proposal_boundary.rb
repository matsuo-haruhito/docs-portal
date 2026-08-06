#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

REPO_ROOT = Pathname.new(File.expand_path("../..", __dir__))

CHECKS = [
  {
    path: "docs/specs/正式レビュー承認workflow境界メモ.md",
    expected: [
      "正式なレビュー・承認 workflow を設計する前に",
      "新しい workflow state、通知、SLA、担当者割当、多段承認、権限変更、承認 UI はここでは定義しません",
      "current support の棚卸し",
      "human decision 待ちに戻す論点"
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
  puts "formal review current/proposal boundary check passed."
  exit 0
else
  warn "formal review current/proposal boundary check failed:"
  errors.each { |e| warn "  - #{e}" }
  exit 1
end
