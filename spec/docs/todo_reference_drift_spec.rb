require "rails_helper"
require "pathname"
require "uri"

RSpec.describe "ToDo reference drift" do
  Link = Struct.new(:source_path, :destination, :resolved_path, keyword_init: true)

  REPO_ROOT = Rails.root
  TODO_PATH = REPO_ROOT.join("docs/ToDo.md")
  INLINE_LINK_PATTERN = /(?<!!)(?:\[[^\]]+\])\(([^)]+)\)/
  EXTERNAL_DESTINATION_PATTERN = %r{\A(?:[a-z][a-z0-9+.-]*:)?//}i
  REQUIRED_CLASSIFICATION_CUES = [
    "具体 Issue があるもの",
    "正本 docs へ移動済み",
    "人間判断待ち",
    "未起票のまま残すもの"
  ].freeze
  ISSUE_REFERENCE_CONTEXT_CUES = [
    "分類:",
    "正本 docs",
    "人間判断待ち",
    "dependency wait",
    "具体 Issue",
    "completed"
  ].freeze

  it "keeps ToDo relative file links pointing at repo files" do
    links = markdown_file_links(TODO_PATH)
    missing_links = links.reject { |link| link.resolved_path.exist? }

    expect(missing_links.map { |link| format_missing_link(link) }).to be_empty
  end

  it "keeps issue references framed by classification context" do
    source = TODO_PATH.read
    lines_with_issue_references = source.lines.select { |line| line.match?(/#\d+/) }
    unclassified_lines = lines_with_issue_references.reject do |line|
      ISSUE_REFERENCE_CONTEXT_CUES.any? { |cue| line.include?(cue) }
    end

    aggregate_failures do
      expect(source.scan(/#\d+/).uniq).not_to be_empty
      REQUIRED_CLASSIFICATION_CUES.each do |cue|
        expect(source).to include(cue)
      end
      expect(unclassified_lines.map(&:strip)).to be_empty
    end
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
