#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

REPO_ROOT = Pathname.new(File.expand_path("../..", __dir__))

CHECKS = [
  {
    path: "docs/テスト方針.md",
    expected: [
      "host app visual evidence comment guide の確認",
      "browser visual evidence: not checked in this PR",
      "CI success、request spec success、source guard success、browser visual evidence を混同しないこと",
      "PR comment、source Issue comment、follow-up visual evidence Issue comment のどこに残すかを短く選べること"
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
  puts "visual evidence comment boundary check passed."
  exit 0
else
  warn "visual evidence comment boundary check failed:"
  errors.each { |e| warn "  - #{e}" }
  exit 1
end
