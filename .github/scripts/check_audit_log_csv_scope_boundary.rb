#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

REPO_ROOT = Pathname.new(File.expand_path("../..", __dir__))

CHECKS = [
  {
    path: "docs/runbooks/admin/監査ログ運用runbook.md",
    expected: [
      "最新 200 件",
      "metadata JSON は監査ログ行データそのものではありません",
      "CSV条件metadata JSON",
      "表示中ページmetadata JSON"
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
  puts "audit log CSV scope boundary check passed."
  exit 0
else
  warn "audit log CSV scope boundary check failed:"
  errors.each { |e| warn "  - #{e}" }
  exit 1
end
