require "rails_helper"

RSpec.describe DocumentReviewComment, type: :model do
  let(:document) { create(:document) }
  let(:version) { create(:document_version, document:) }
  let(:internal_user) { create(:user, :internal) }
  let(:external_user) { create(:user, :external) }

  it "allows internal authors to create internal review comments" do
    comment = build(
      :document_review_comment,
      document:,
      document_version: version,
      author: internal_user,
      comment_type: :request_change,
      body: "Please revise this section."
    )

    expect(comment).to be_valid
  end

  it "rejects external authors" do
    comment = build(:document_review_comment, document:, author: external_user)

    expect(comment).not_to be_valid
    expect(comment.errors[:author]).to be_present
  end

  it "is visible only to internal users" do
    comment = create(:document_review_comment, document:, author: internal_user)

    expect(described_class.visible_to(internal_user)).to include(comment)
    expect(described_class.visible_to(external_user)).not_to include(comment)
  end

  it "requires comments to remain internal only" do
    comment = build(:document_review_comment, document:, internal_only: false)

    expect(comment).not_to be_valid
    expect(comment.errors[:internal_only]).to be_present
  end

  it "requires document versions to belong to the same document" do
    other_version = create(:document_version)
    comment = build(:document_review_comment, document:, document_version: other_version)

    expect(comment).not_to be_valid
    expect(comment.errors[:document_version]).to be_present
  end

  it "resolves comments with resolver and timestamp" do
    comment = create(:document_review_comment, document:, author: internal_user)

    comment.resolve!(internal_user)

    expect(comment).to be_resolved
    expect(comment.resolved_by).to eq(internal_user)
    expect(comment.resolved_at).to be_present
  end

  it "rejects resolved status without resolver metadata" do
    comment = build(:document_review_comment, document:, status: :resolved, resolved_by: nil, resolved_at: nil)

    expect(comment).not_to be_valid
    expect(comment.errors[:resolved_by]).to be_present
    expect(comment.errors[:resolved_at]).to be_present
  end

  it "uses public_id for routes" do
    comment = create(:document_review_comment, document:, author: internal_user)

    expect(comment.to_param).to eq(comment.public_id)
  end
end
