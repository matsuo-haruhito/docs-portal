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

  ALLOWLISTED_ORPHANS = {
    "docs/specs/search.md" => "search responsibility spec is intentionally topic-specific and not a first-read index entry yet"
  }.freeze

  INDEX_PATHS = [
    "README.md",
    "docs/README.md"
  ].freeze

  attr_reader :root

  def initialize(root)
    @root = Pathname.new(root)
  end

  def run
    missing_index_entries = target_docs.reject do |relative_path|
      indexed_paths.include?(relative_path) || ALLOWLISTED_ORPHANS.key?(relative_path)
    end

    missing_index_entries.map do |relative_path|
      "#{relative_path}: missing from README.md/docs/README.md and not allowlisted"
    end
  end

  def self_test!
    Dir.mktmpdir do |dir|
      root = Pathname.new(dir)
      root.join("docs/specs").mkpath

      write(root.join("README.md"), "- [normal](./docs/通常runbook.md)\n")
      write(root.join("docs/README.md"), "- [encoded](./%E6%97%A5%E6%9C%AC%E8%AA%9Erunbook.md)\n")
      write(root.join("docs/通常runbook.md"), "# normal\n")
      write(root.join("docs/日本語runbook.md"), "# encoded\n")
      write(root.join("docs/specs/search.md"), "# allowlisted\n")
      write(root.join("docs/未掲載runbook.md"), "# orphan\n")

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
