#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

REPO_ROOT = Pathname.new(File.expand_path("../..", __dir__))

CHECKS = [
  ["docusaurus/package.json", "\"smoke:kroki\": \"node --test plugins/remark-kroki-diagrams.smoke.test.mjs\""],
  [".github/workflows/docs-quality.yml", "npm run smoke:kroki"],
  ["docusaurus/plugins/remark-kroki-diagrams.smoke.test.mjs", "fetchImpl: async (url, init) =>"],
  ["docusaurus/plugins/remark-kroki-diagrams.smoke.test.mjs", "KROKI_ENDPOINT is required to render d2 diagrams"],
  ["docusaurus/plugins/remark-kroki-diagrams.mjs", "file?.path ?? 'unknown file'"],
  [".env.example", "KROKI_ENDPOINT=http://kroki:8000"],
  ["docker-compose.kroki.yml", "KROKI_ENDPOINT: ${KROKI_ENDPOINT:-http://kroki:8000}"],
  ["docker-compose.kroki.yml", "image: yuzutech/kroki"],
  ["docs/notes/docusaurus-build-runtime.md", "The smoke keeps Kroki optional by passing a mocked fetch implementation."],
  ["docs/notes/docusaurus-build-runtime.md", "should pass without a running Kroki service"],
  ["docs/notes/docusaurus-build-runtime.md", "Do not commit the generated SVG."],
  ["docs/ローカルセットアップと環境変数.md", "docker-compose.yml:docker-compose.kroki.yml:docker-compose.docusaurus.yml"],
  ["docs/ローカルセットアップと環境変数.md", "KROKI_ENDPOINT=http://kroki:8000"]
].freeze

errors = []

CHECKS.each do |relative_path, expected_text|
  path = REPO_ROOT.join(relative_path)
  unless path.file?
    errors << "#{relative_path}: missing file"
    next
  end

  content = path.read
  next if content.include?(expected_text)

  errors << "#{relative_path}: missing expected Kroki boundary text: #{expected_text.inspect}"
end

if errors.any?
  warn "Kroki optional runtime docs/source guard failed:"
  errors.each { |error| warn "- #{error}" }
  exit 1
end

puts "Kroki optional runtime docs/source guard passed."
