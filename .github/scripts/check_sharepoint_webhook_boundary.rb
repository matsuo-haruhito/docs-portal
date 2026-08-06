#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

REPO_ROOT = Pathname.new(File.expand_path("../..", __dir__))

CHECKS = [
  {
    path: "docs/runbooks/external/外部フォルダ同期dry-run・apply運用runbook.md",
    expected: [
      "SharePoint webhook route は validation token 応答と notification payload 記録の受け口として存在します",
      "webhook route があるだけでは、SharePoint / OneDrive の変更通知を運用可能とは扱いません",
      "GET または POST で `validationToken` が渡された場合は plain text で返し、イベントは記録しません",
      "Graph subscription 作成や通知起点の同期運用ができる状態ではありません"
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
  puts "SharePoint webhook boundary check passed."
  exit 0
else
  warn "SharePoint webhook boundary check failed:"
  errors.each { |error| warn "  - #{error}" }
  exit 1
end
