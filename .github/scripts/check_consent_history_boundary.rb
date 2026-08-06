#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

REPO_ROOT = Pathname.new(File.expand_path("../..", __dir__))

CHECKS = [
  {
    path: "docs/runbooks/viewer/利用者向け同意画面・同意履歴runbook.md",
    expected: [
      "個人ユーザー単位の確認履歴",
      "会社間契約、法務承認、契約締結状況の代替としては扱わない"
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
  puts "consent history boundary check passed."
  exit 0
else
  warn "consent history boundary check failed:"
  errors.each { |e| warn "  - #{e}" }
  exit 1
end
