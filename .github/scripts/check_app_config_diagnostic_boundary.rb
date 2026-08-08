#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

REPO_ROOT = Pathname.new(File.expand_path("../..", __dir__))

CHECKS = [
  {
    path: "docs/specs/本番運用・インフラ前提.md",
    expected: [
      "ApplicationConfigurationDiagnostic",
      "health check",
      "DOC_IMPORT_TOKEN",
      "KROKI_ENDPOINT"
    ]
  },
  {
    path: "docs/runbooks/ops/管理ダッシュボード・モデルブラウザ運用runbook.md",
    expected: [
      "ApplicationConfigurationDiagnostic",
      "OK / 警告 / エラー",
      "status filter",
      "category filter"
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
  puts "ApplicationConfigurationDiagnostic health check boundary check passed."
  exit 0
else
  warn "ApplicationConfigurationDiagnostic health check boundary check failed:"
  errors.each { |e| warn "  - #{e}" }
  exit 1
end
