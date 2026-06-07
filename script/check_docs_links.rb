#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"
require "set"
require "uri"

class DocsLinkChecker
  DEFAULT_TARGETS = ["README.md", "docs/README.md"].freeze
  SKIPPED_EXTENSIONS = [".html", ".htm"].freeze

  BrokenLink = Struct.new(:source, :href, :resolved_path, keyword_init: true)

  def initialize(root:, targets: DEFAULT_TARGETS)
    @root = Pathname(root)
    @targets = targets.map { |target| Pathname(target) }
  end

  def broken_links
    targets.flat_map do |target|
      source_path = root.join(target)
      extract_links(source_path.read).filter_map do |href|
        resolved_path = resolve_path(source_path, href)
        next if resolved_path.nil? || resolved_path.exist?

        BrokenLink.new(source: target.to_s, href: href, resolved_path: resolved_path.relative_path_from(root).to_s)
      end
    end
  end

  def valid?
    broken_links.empty?
  end

  private

  attr_reader :root, :targets

  def extract_links(markdown)
    inline_links = markdown.scan(/!?\[[^\]]+\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)/).flatten
    reference_links = markdown.scan(/^\s*\[[^\]]+\]:\s+(\S+)/).flatten

    (inline_links + reference_links).map(&:strip).uniq
  end

  def resolve_path(source_path, href)
    return nil if skipped_href?(href)

    normalized_href = URI::DEFAULT_PARSER.unescape(href.split("#", 2).first.to_s)
    return nil if normalized_href.empty?

    resolved_path = source_path.dirname.join(normalized_href).cleanpath
    relative_path = resolved_path.relative_path_from(root).to_s
    return nil if relative_path == ".." || relative_path.start_with?("../")
    return nil if SKIPPED_EXTENSIONS.include?(resolved_path.extname)

    resolved_path
  end

  def skipped_href?(href)
    href.empty? ||
      href.start_with?("#", "/", "//") ||
      href.match?(%r{\A[a-z][a-z0-9+.-]*:}i)
  end
end

if __FILE__ == $PROGRAM_NAME
  checker = DocsLinkChecker.new(root: Pathname(__dir__).join(".."))
  broken_links = checker.broken_links

  if broken_links.empty?
    puts "README.md and docs/README.md relative links are valid."
    exit 0
  end

  warn "Broken README/docs index links:"
  broken_links.each do |link|
    warn "- #{link.source}: #{link.href} -> #{link.resolved_path}"
  end

  exit 1
end
