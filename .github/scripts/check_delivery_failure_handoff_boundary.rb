#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

REPO_ROOT = Pathname.new(File.expand_path("../..", __dir__))

CHECKS = [
  {
    path: "docs/runbooks/external/外部送付履歴継続失敗候補runbook.md",
    expected: [
      "read-only に抽出",
      "read-only service",
      "通知 channel、alert rule、自動 retry、ack / escalation はここでは定義しません",
      "通知送信、ack、自動 retry、送付状態変更は行いません",
      "read-only handoff であり、通知や状態変更は行わない",
      "送付状態の変更や本番 alert 発火を意味しません"
    ]
  },
  {
    path: "docs/runbooks/external/外部送付履歴運用runbook.md",
    expected: [
      "送付済み",
      "送付失敗"
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
  puts "delivery failure handoff boundary check passed."
  exit 0
else
  warn "delivery failure handoff boundary check failed:"
  errors.each { |error| warn "  - #{error}" }
  exit 1
end
