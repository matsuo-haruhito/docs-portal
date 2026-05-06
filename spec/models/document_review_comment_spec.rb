require "rails_helper"

RSpec.describe DocumentReviewComment, type: :model do
  let(:document) { create(:document) }
  let(:version) { create(:document_version, document:) }
  let(:author) { create(:user, :internal) }

  it "accepts line and anchor metadata" do
    comment = build(
      :document_review_comment,
      document:,
      document_version: version,
      author:,
      text_line_start: 10,
      text_line_end: 14,
      text_anchor_type: "markdown_heading",
      text_anchor_path: "要件定義 > 画面要件",
      text_anchor_label: "画面要件",
      source_path: "docs/spec.md"
    )

    expect(comment).to be_valid
    expect(comment.location_label).to include("lines 10-14")
    expect(comment.location_label).to include("要件定義 > 画面要件")
  end

  it "requires parent comments to belong to the same document" do
    other_document = create(:document)
    parent = create(:document_review_comment, document: other_document)
    comment = build(:document_review_comment, document:, parent:)

    expect(comment).not_to be_valid
    expect(comment.errors[:parent]).to be_present
  end

  it "allows public Q&A threads from external users" do
    external_author = create(:user, :external, company: create(:company))
    comment = build(
      :document_review_comment,
      document:,
      document_version: version,
      author: external_author,
      comment_type: :question,
      internal_only: false
    )

    expect(comment).to be_valid
    expect(comment.public_thread?).to eq(true)
    expect(comment.qa_status_label).to eq("受付中")
  end
end
