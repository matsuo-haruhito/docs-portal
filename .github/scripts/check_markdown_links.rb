#!/usr/bin/env ruby
# frozen_string_literal: true

require "cgi"
require "pathname"

REPO_ROOT = Pathname.new(File.expand_path("../..", __dir__))
MARKDOWN_FILES = Dir.glob(["README.md", "docs/**/*.md"], base: REPO_ROOT.to_s).sort.freeze
LINK_PATTERN = /!?\[[^\]]*\]\(([^)]+)\)/.freeze
SKIPPED_SCHEMES = /\A(?:https?:|mailto:|tel:|data:)/i.freeze


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
  destination.split(/\s+[\"']/, 2).first
end


def resolve_target(markdown_file, destination)
  return if destination.empty? || destination.start_with?("#") || destination.match?(SKIPPED_SCHEMES)

  path_part = destination.split("#", 2).first
  return if path_part.empty?

  decoded_path = CGI.unescape(path_part)
  if decoded_path.start_with?("/")
    REPO_ROOT.join(decoded_path.delete_prefix("/")).cleanpath
  else
    markdown_file.dirname.join(decoded_path).cleanpath
  end
end

errors = []

MARKDOWN_FILES.each do |relative_path|
  markdown_file = REPO_ROOT.join(relative_path)

  markdown_lines(markdown_file).each_with_index do |line, line_index|
    line.scan(LINK_PATTERN) do |match|
      destination = extract_destination(match.first)
      target = resolve_target(markdown_file, destination)
      next unless target
      next if target.exist?

      errors << "#{relative_path}:#{line_index + 1} -> #{destination} (missing: #{target.relative_path_from(REPO_ROOT)})"
    end
  end
end

if errors.any?
  warn "Broken relative Markdown links detected:"
  errors.each { |error| warn "- #{error}" }
  exit 1
end

puts "Checked #{MARKDOWN_FILES.size} Markdown files: no broken relative links found."
