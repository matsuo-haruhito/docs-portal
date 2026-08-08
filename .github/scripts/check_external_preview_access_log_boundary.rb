#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

REPO_ROOT = Pathname.new(File.expand_path("../..", __dir__))

CHECKS = [
  {
    path: "docs/runbooks/import/案件・Git連携・文書セット初回セットアップrunbook.md",
    expected: [
      "実ログイン切り替えではなく",
      "AccessLog` に `external_preview` として記録される",
      "実際の社外ユーザーがログインして閲覧した記録ではない"
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
  puts "external preview AccessLog boundary check passed."
  exit 0
else
  warn "external preview AccessLog boundary check failed:"
  errors.each { |e| warn "  - #{e}" }
  exit 1
end
