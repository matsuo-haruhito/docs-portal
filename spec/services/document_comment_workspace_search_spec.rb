require "rails_helper"

RSpec.describe DocumentCommentWorkspaceSearch do
  let(:user) { build_stubbed(:user, :internal) }

  it "strips and slices oversized queries before exposing the active query" do
    normalized_query = "AbC" * 40
    search = described_class.new(user:, query: "  #{normalized_query}tail  ")

    expect(search.query).to eq(normalized_query.slice(0, described_class::COMMENT_QUERY_MAX_LENGTH))
    expect(search.query.length).to eq(described_class::COMMENT_QUERY_MAX_LENGTH)
  end

  it "uses the sliced query for case-insensitive review matching" do
    matching_body = "a" * described_class::COMMENT_QUERY_MAX_LENGTH
    oversized_query = "  #{matching_body}ignored-tail"
    matching_comment = Struct.new(:body, :source_path, :text_anchor_path, :text_anchor_label, :location_label).new(
      "#{matching_body} visible body",
      nil,
      nil,
      nil,
      nil
    )
    non_matching_comment = Struct.new(:body, :source_path, :text_anchor_path, :text_anchor_label, :location_label).new(
      "ignored-tail only",
      nil,
      nil,
      nil,
      nil
    )

    search = described_class.new(user:, query: oversized_query)

    expect(search.filter_reviews([matching_comment, non_matching_comment])).to eq([matching_comment])
  end
end
