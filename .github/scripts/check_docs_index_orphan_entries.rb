#!/usr/bin/env ruby
# frozen_string_literal: true

require "cgi"
require "pathname"
require "tmpdir"

class DocsIndexOrphanEntriesCheck
  LINK_PATTERN = /!?\[[^\]]*\]\(([^)]+)\)/.freeze
  SKIPPED_SCHEMES = /\A(?:https?:|mailto:|tel:|data:)/i.freeze

  TARGET_PATTERNS = [
    "docs/**/*runbook*.md",
    "docs/specs/*.md"
  ].freeze

  # Keep this allowlist narrow. A target doc should be linked from README.md or docs/README.md
  # when it is a first-read entry; otherwise keep it here with a category and a short reason
  # for staying outside that first-read index. Link existence and anchor coverage belong to
  # the separate markdown-link checks such as #2585.
  ALLOWLIST_REASON_CATEGORIES = {
    "nested-index" => "nested-index",
    "topic-specific" => "topic-specific",
    "focused-reference" => "focused-reference",
    "ui-cue-reference" => "ui-cue-reference",
    "failure-handoff-reference" => "failure-handoff-reference"
  }.freeze

  def self.allowlist_reason(category, detail)
    "#{ALLOWLIST_REASON_CATEGORIES.fetch(category)}: #{detail}"
  end

  ALLOWLISTED_ORPHANS = {
    "docs/specs/README.md" => allowlist_reason("nested-index", "specs sub-index is kept behind representative specs links rather than the first-read index"),
    "docs/specs/archive-preview.md" => allowlist_reason("topic-specific", "archive preview spec is intentionally outside the first-read index"),
    "docs/specs/docusaurus-build-manifest.md" => allowlist_reason("focused-reference", "build manifest spec is an implementation reference, not a primary index entry"),
    "docs/specs/path-history-redirect.md" => allowlist_reason("focused-reference", "path history redirect spec is an implementation reference, not a primary index entry"),
    "docs/specs/preview-target-metadata.md" => allowlist_reason("focused-reference", "preview target metadata spec is an implementation reference, not a primary index entry"),
    "docs/specs/search.md" => allowlist_reason("topic-specific", "search responsibility spec remains topic-specific until promoted to a first-read entry"),
    "docs/specs/生成ファイルイベント.md" => allowlist_reason("focused-reference", "generated file event spec is an implementation reference, not a primary index entry"),
    "docs/グローバルナビ分類・開閉導線runbook.md" => allowlist_reason("ui-cue-reference", "global nav classification runbook is a narrow UI cue reference"),
    "docs/外部送付履歴継続失敗候補runbook.md" => allowlist_reason("failure-handoff-reference", "delivery failure candidate runbook is a specialized failure handoff reference")
  }.freeze

  ALLOWLIST_REASON_PREFIXES = ALLOWLIST_REASON_CATEGORIES.values.map { |category| "#{category}:" }.freeze

  INDEX_PATHS = [
    "README.md",
    "docs/README.md"
  ].freeze

  attr_reader :root

  def initialize(root)
    @root = Pathname.new(root)
  end

  def run
    self.class.validate_allowlist_reasons!

    missing_index_entries = target_docs.reject do |relative_path|
      indexed_paths.include?(relative_path) || ALLOWLISTED_ORPHANS.key?(relative_path)
    end

    missing_index_entries.map do |relative_path|
      "#{relative_path}: missing from README.md/docs/README.md and not allowlisted"
    end
  end

  def self.validate_allowlist_reasons!
    invalid_entries = ALLOWLISTED_ORPHANS.reject do |_path, reason|
      ALLOWLIST_REASON_PREFIXES.any? { |prefix| reason.start_with?(prefix) }
    end
    return if invalid_entries.empty?

    invalid_paths = invalid_entries.keys.sort.join(", ")
    raise ArgumentError, "Docs index orphan allowlist reasons need a known category: #{invalid_paths}"
  end

  def self.self_test!
    Dir.mktmpdir do |dir|
      root = Pathname.new(dir)
      root.join("docs/specs").mkpath

      self.write(root.join("README.md"), "- [normal](./docs/通常runbook.md)\n")
      self.write(root.join("docs/README.md"), "- [encoded](./%E6%97%A5%E6%9C%AC%E8%AA%9Erunbook.md)\n")
      self.write(root.join("docs/通常runbook.md"), "# normal\n")
      self.write(root.join("docs/日本語runbook.md"), "# encoded\n")
      self.write(root.join("docs/specs/search.md"), "# allowlisted\n")
      self.write(root.join("docs/未掲載runbook.md"), "# orphan\n")

      errors = new(root).run
      expected_error = "docs/未掲載runbook.md: missing from README.md/docs/README.md and not allowlisted"

      unless errors == [expected_error]
        abort <<~MESSAGE
          docs index orphan self-test failed.
          Expected: #{[expected_error].inspect}
          Actual:   #{errors.inspect}
        MESSAGE
      end
    end

    puts "docs index orphan self-test passed."
  end

  def self.write(path, content)
    path.dirname.mkpath
    path.write(content)
  end

  private

  def target_docs
    Dir.glob(TARGET_PATTERNS, base: root.to_s).sort.select do |relative_path|
      root.join(relative_path).file?
    end
  end

  def indexed_paths
    @indexed_paths ||= INDEX_PATHS.each_with_object({}) do |relative_path, paths|
      index_path = root.join(relative_path)
      next unless index_path.file?

      markdown_lines(index_path).each do |line|
        line.scan(LINK_PATTERN) do |match|
          destination = extract_destination(match.first)
          target = resolve_target(index_path, destination)
          next unless target

          paths[target.relative_path_from(root).to_s] = true if target.to_s.start_with?(root.to_s)
        end
      end
    end
  end

  def markdown_lines(path)
    in_fence = false

    path.each_line.filter_map do |line|
      stripped = line.lstrip
      if stripped.start_with?("```", "~~~")
        in_fence = !in_fence
        next
      end

      next if in_fence

      line
    end
  end

  def extract_destination(raw_destination)
    destination = raw_destination.strip
    destination = destination.sub(/\A<(.+)>\z/, "\\1")
    destination.split(/\s+["']/, 2).first
  end

  def resolve_target(markdown_file, destination)
    return if destination.empty? || destination.start_with?("#") || destination.match?(SKIPPED_SCHEMES)

    path_part = destination.split("#", 2).first
    return if path_part.empty?

    decoded_path = CGI.unescape(path_part)
    if decoded_path.start_with?("/")
      root.join(decoded_path.delete_prefix("/")).cleanpath
    else
      markdown_file.dirname.join(decoded_path).cleanpath
    end
  end
end

if ARGV.include?("--self-test")
  DocsIndexOrphanEntriesCheck.self_test!
  exit
end

errors = DocsIndexOrphanEntriesCheck.new(File.expand_path("../..", __dir__)).run

if errors.any?
  warn "Docs index orphan entries detected:"
  errors.each { |error| warn "- #{error}" }
  warn "Add the document to README.md or docs/README.md, or add a narrow allowlist reason in this script."
  exit 1
end

puts "Docs index orphan check passed."
