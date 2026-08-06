#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

REPO_ROOT = Pathname.new(File.expand_path("../..", __dir__))

CHECKS = [
  {
    path: "README.md",
    expected: [
      "ローカル開発 / demo 専用アカウント",
      "共有環境や本番へ転用する credential ではなく",
      "本番 credential や認証 policy の例でもありません"
    ]
  },
  {
    path: "docs/guides/ローカルセットアップと環境変数.md",
    expected: [
      "ローカル開発 / demo 専用 seed アカウント",
      "共有環境や本番へ転用する credential でも、本番 credential / 認証 policy の例でもありません",
      "demo credential / placeholder secret の変更時チェック",
      "placeholder として読む",
      "production credential の推奨値として扱わない"
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
  puts "demo credential / placeholder secret boundary check passed."
  exit 0
else
  warn "demo credential / placeholder secret boundary check failed:"
  errors.each { |error| warn "  - #{error}" }
  exit 1
end
