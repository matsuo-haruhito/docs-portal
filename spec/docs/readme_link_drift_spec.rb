require "rails_helper"
require "pathname"
require "uri"

RSpec.describe "README index link drift" do
  Link = Struct.new(:source_path, :destination, :resolved_path, keyword_init: true)

  REPO_ROOT = Rails.root
  INDEX_FILES = [
    REPO_ROOT.join("README.md"),
    REPO_ROOT.join("docs/README.md")
  ].freeze
  INLINE_LINK_PATTERN = /(?<!!)(?:\[[^\]]+\])\(([^)]+)\)/
  EXTERNAL_DESTINATION_PATTERN = %r{\A(?:[a-z][a-z0-9+.-]*:)?//}i

  it "keeps README and docs index relative file links pointing at repo files" do
    links = INDEX_FILES.flat_map { |source_path| markdown_file_links(source_path) }
    missing_links = links.reject { |link| link.resolved_path.exist? }

    expect(missing_links.map { |link| format_missing_link(link) }).to be_empty
  end

  it "covers the representative encoded and relative links used by the indexes" do
    destinations_by_source = INDEX_FILES.to_h do |source_path|
      [source_path.relative_path_from(REPO_ROOT).to_s, markdown_file_links(source_path).map(&:destination)]
    end

    expect(destinations_by_source.fetch("README.md")).to include(
      "./Product%20Profile.md",
      "./docs/README.md",
      "./docs/specs/ダッシュボードと文書ショートカット・確認依頼の使い分け.md"
    )
    expect(destinations_by_source.fetch("docs/README.md")).to include(
      "../Product%20Profile.md",
      "./アプリケーション仕様.md",
      "../.kiro/steering/frontend-interaction-policy.md"
    )
  end

  def markdown_file_links(source_path)
    source_path.read.scan(INLINE_LINK_PATTERN).flatten.filter_map do |raw_destination|
      destination = normalize_markdown_destination(raw_destination)
      next if ignored_destination?(destination)

      target_path = destination.split(/[?#]/, 2).first
      decoded_path = URI::DEFAULT_PARSER.unescape(target_path)
      resolved_path = source_path.dirname.join(decoded_path).cleanpath
      next unless resolved_path.to_s.start_with?(REPO_ROOT.to_s)

      Link.new(source_path:, destination:, resolved_path:)
    end
  end

  def normalize_markdown_destination(raw_destination)
    raw_destination.strip.delete_prefix("<").delete_suffix(">").split(/\s+/, 2).first.to_s
  end

  def ignored_destination?(destination)
    destination.blank? ||
      destination.start_with?("#") ||
      destination.match?(EXTERNAL_DESTINATION_PATTERN) ||
      destination.match?(/\A[a-z][a-z0-9+.-]*:/i)
  end

  def format_missing_link(link)
    source = link.source_path.relative_path_from(REPO_ROOT)
    target = link.resolved_path.to_s.delete_prefix("#{REPO_ROOT}/")
    "#{source}: #{link.destination} -> #{target}"
  end
end
