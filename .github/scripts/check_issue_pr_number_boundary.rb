#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

REPO_ROOT = Pathname.new(File.expand_path("../..", __dir__))

CHECKS = [
  {
    path: "README.md",
    expected: [
      "Issue / PR 番号",
      "current support の証跡",
      "historical evidence",
      "次に見る候補",
      "番号だけで current action を判断せず",
      "リンク先 runbook / ROADMAP の文脈と current code"
    ]
  },
  {
    path: "docs/README.md",
    expected: [
      "Issue / PR 番号",
      "current support の証跡",
      "historical evidence",
      "次に見る候補",
      "proposal",
      "番号だけを current action とせず",
      "各 docs の本文、ROADMAP の文脈、current code"
    ]
  },
  {
    path: "ROADMAP.md",
    expected: [
      "代表 issue / PR",
      "current support の証跡",
      "historical evidence",
      "次に見る未解決候補",
      "`PR #... は merged`",
      "`current support`",
      "`docs 同期`",
      "`完了済み`",
      "再実装や refresh 対象ではなく",
      "#1333、#1986、PR #1366 のような完了済み番号",
      "open blocker として見る番号",
      "`候補`",
      "`次に見る`",
      "`proposal`",
      "`release train gate`",
      "`needs-human`",
      "closed / merged PR 番号だけが current next action"
    ]
  }
].freeze

errors = []

CHECKS.each do |check|
  relative_path = check.fetch(:path)
  path = REPO_ROOT.join(relative_path)

  unless path.file?
    errors << "#{relative_path}: missing file"
    next
  end

  content = path.read
  check.fetch(:expected).each do |expected_text|
    next if content.include?(expected_text)

    errors << "#{relative_path}: missing expected Issue / PR number boundary text: #{expected_text.inspect}"
  end
end

if errors.any?
  warn "Issue / PR number boundary guard failed:"
  errors.each { |error| warn "- #{error}" }
  exit 1
end

puts "Issue / PR number boundary guard passed."
