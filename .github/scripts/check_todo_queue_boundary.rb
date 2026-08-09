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
lines = content.lines

REQUIRED_PATTERNS = [
  /実装済み・close 済みの項目/,
  /具体 Issue があるもの.*Issue 番号.*正本 docs.*判断論点/m,
  /未起票のまま残す項目.*まだ起票しない理由/m,
  /人間判断待ち/,
  /未起票のまま残すもの/,
  /close 済み Issue を進行中キューとして残さない/
].freeze

REQUIRED_PATTERNS.each do |pattern|
  next if content.match?(pattern)

  errors << "docs/ToDo.md: missing queue boundary: #{pattern.inspect}"
end

CLOSED_QUEUE_REFERENCES = %w[
  #475 #758 #760 #1112 #1162 #1246 #1266 #1300 #1604 #1613 #1614
  #2224 #2766 #3268 #3269 #3418 #3421 #4071 #4486 #4761
].freeze

CLOSED_QUEUE_REFERENCES.each do |reference|
  bare_reference = /(?<![[:alnum:]_.-])#{Regexp.escape(reference)}(?!\d)/
  qualified_reference = /docs-portal#{Regexp.escape(reference)}(?!\d)/
  next unless content.match?(bare_reference) || content.match?(qualified_reference)

  errors << "docs/ToDo.md: closed item remains in active future queue: #{reference}"
end

BROAD_UMBRELLA_CHECKS = [
  {
    label: "社内 / 社外 / 管理者ごとの導線差分",
    required: [
      "分類は未起票のまま残すもの",
      "まだ起票しない理由は、対象画面、導線差分、受け入れ条件が画面群ごとに固まっていない"
    ]
  },
  {
    label: "総合 UI/UX 見直し",
    required: [
      "分類は未起票のまま残すもの",
      "まだ起票しない理由は、broad umbrella では review と acceptance が大きすぎる"
    ]
  },
  {
    label: "安定化を進める",
    required: [
      "broad umbrella issue は原則として維持しない",
      "まだ起票しない理由は、再現した問題、対象 job / spec、観測指標、受け入れ条件が揃うまで umbrella では扱えない"
    ]
  }
].freeze

BROAD_UMBRELLA_CHECKS.each do |check|
  index = lines.index { |candidate| candidate.include?(check.fetch(:label)) }

  unless index
    errors << "docs/ToDo.md: missing representative broad umbrella item: #{check.fetch(:label).inspect}"
    next
  end

  nearby_text = lines[index, 8].join
  check.fetch(:required).each do |expected_text|
    next if nearby_text.include?(expected_text)

    errors << "docs/ToDo.md: #{check.fetch(:label)} is missing nearby queue-boundary text: #{expected_text.inspect}"
  end
end

lines.grep(/^- .*分類(?:は|:).*具体 Issue あり/).each do |line|
  next if line.match?(/#\d+/)

  errors << "docs/ToDo.md: concrete Issue item lacks an Issue number: #{line.strip}"
end

lines.each_with_index do |line, index|
  next unless line.include?("分類は未起票のまま残すもの")

  nearby_text = lines[index, 3].join
  next if nearby_text.include?("まだ起票しない理由")

  errors << "docs/ToDo.md: unfiled item lacks a reason near line #{index + 1}"
end

if errors.any?
  warn "ToDo queue boundary guard failed:"
  errors.each { |error| warn "- #{error}" }
  exit 1
end

puts "ToDo queue boundary docs guard passed."
