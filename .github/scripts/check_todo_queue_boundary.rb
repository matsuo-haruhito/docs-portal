#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

REPO_ROOT = Pathname.new(File.expand_path("../..", __dir__))
TODO_PATH = REPO_ROOT.join("docs/ToDo.md")

errors = []

unless TODO_PATH.file?
  warn "docs/ToDo.md: missing file"
  exit 1
end

content = TODO_PATH.read

REQUIRED_BOUNDARY_TEXT = [
  "具体 Issue があるものは、この文書に要件を重複して残さず、Issue 番号と正本 docs への導線だけを残す",
  "未起票のまま残す項目は、まだ起票しない理由を短く添える",
  "具体 Issue があるもの: ToDo 側では Issue 番号、正本 docs、残る判断論点だけを残し",
  "未起票のまま残すもの: 具体画面、運用痛点、再現条件、または受け入れ条件が固まった時点で concrete issue に切り出す"
].freeze

REQUIRED_BOUNDARY_TEXT.each do |expected_text|
  next if content.include?(expected_text)

  errors << "docs/ToDo.md: missing ToDo queue boundary text: #{expected_text.inspect}"
end

BROAD_UMBRELLA_CHECKS = [
  {
    label: "社内 / 社外 / 管理者ごとの導線差分",
    required: [
      "分類: 未起票のまま残すもの",
      "まだ起票しない理由: 対象画面、導線差分、受け入れ条件が画面群ごとに固まっていない"
    ]
  },
  {
    label: "総合 UI/UX 見直し",
    required: [
      "分類: 未起票のまま残すもの",
      "まだ起票しない理由: broad umbrella では review / acceptance が大きすぎる"
    ]
  },
  {
    label: "安定化を進める",
    required: [
      "broad umbrella issue は原則として維持しない",
      "まだ起票しない理由: 再現した問題、対象 job/spec、観測指標、受け入れ条件が揃うまで umbrella では扱わない"
    ]
  }
].freeze

BROAD_UMBRELLA_CHECKS.each do |check|
  line = content.lines.find { |candidate| candidate.include?(check.fetch(:label)) }

  unless line
    errors << "docs/ToDo.md: missing representative broad umbrella item: #{check.fetch(:label).inspect}"
    next
  end

  check.fetch(:required).each do |expected_text|
    next if line.include?(expected_text)

    errors << "docs/ToDo.md: #{check.fetch(:label)} is missing nearby queue-boundary text: #{expected_text.inspect}"
  end
end

concrete_issue_lines = content.lines.select { |line| line.include?("分類: 具体 Issue") }
concrete_issue_lines.each do |line|
  next if line.match?(/#\d+/) || line.include?("正本 docs")

  errors << "docs/ToDo.md: concrete Issue item lacks an Issue number or source-doc route: #{line.strip}"
end

if errors.any?
  warn "ToDo queue boundary guard failed:"
  errors.each { |error| warn "- #{error}" }
  exit 1
end

puts "ToDo queue boundary docs guard passed."
