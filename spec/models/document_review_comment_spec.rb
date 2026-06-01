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

  it "requires internal-only comments to be authored by internal users" do
    external_author = create(:user, :external, company: create(:company))
    comment = build(
      :document_review_comment,
      document:,
      document_version: version,
      author: external_author,
      comment_type: :request_change,
      internal_only: true
    )

    expect(comment).not_to be_valid
    expect(comment.errors[:author]).to include("must be internal")
  end

  it "requires parent comments to belong to the same document" do
    other_document = create(:document)
    parent = create(:document_review_comment, document: other_document)
    comment = build(:document_review_comment, document:, parent:)

    expect(comment).not_to be_valid
    expect(comment.errors[:parent]).to be_present
  end

  it "requires replies to match parent visibility" do
    public_parent = create(
      :document_review_comment,
      document:,
      document_version: version,
      author:,
      comment_type: :question,
      internal_only: false
    )
    comment = build(
      :document_review_comment,
      document:,
      document_version: version,
      parent: public_parent,
      author:,
      comment_type: :request_change,
      internal_only: true
    )

    expect(comment).not_to be_valid
    expect(comment.errors[:internal_only]).to include("must match parent visibility")
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

  it "requires resolved comments to carry resolver metadata" do
    comment = build(
      :document_review_comment,
      document:,
      document_version: version,
      author:,
      status: :resolved,
      resolved_by: nil,
      resolved_at: nil
    )

    expect(comment).not_to be_valid
    expect(comment.errors[:resolved_by]).to include("must be present")
    expect(comment.errors[:resolved_at]).to include("must be present")
  end

  it "rejects resolver metadata on unresolved comments" do
    comment = build(
      :document_review_comment,
      document:,
      document_version: version,
      author:,
      status: :open,
      resolved_by: author,
      resolved_at: Time.current
    )

    expect(comment).not_to be_valid
    expect(comment.errors[:status]).to include("must be resolved when resolved fields are present")
  end

  it "accepts resolved comments with matching resolver metadata" do
    comment = build(
      :document_review_comment,
      document:,
      document_version: version,
      author:,
      status: :resolved,
      resolved_by: author,
      resolved_at: Time.current
    )

    expect(comment).to be_valid
    expect(comment.qa_status_label).to eq("回答済み")
  end
end
