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
    path: "ROADMAP.md",
    expected: [
      "ここに書かないもの: 完了済み・close 済み Issue",
      "将来対応・保留事項は [ToDo](docs/ToDo.md) を正本にする",
      "## 候補を追加する条件",
      "active queue に置かない"
    ]
  },
  {
    path: "docs/ToDo.md",
    expected: [
      "具体 Issue があるものは、この文書に要件を重複して残さず",
      "**具体 Issue あり**",
      "close 済み Issue を進行中キューとして残さない"
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
