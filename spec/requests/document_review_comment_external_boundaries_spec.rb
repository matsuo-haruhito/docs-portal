require "rails_helper"

RSpec.describe "Document review comment external boundaries", type: :request do
  let(:internal_user) { create(:user, :internal) }
  let(:company) { create(:company) }
  let(:external_user) { create(:user, :external, company:) }
  let(:project) { create(:project, code: "REVIEW", name: "Review Project") }
  let(:document) { create(:document, project:, title: "Review Manual", slug: "review-manual", visibility_policy: :restricted_external) }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0", status: :published) }

  before do
    document.update!(latest_version: version)
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document:, company:, access_level: :view)
  end

  it "shows public version Q&A but hides internal-only version review comments from external users" do
    create(
      :document_review_comment,
      document:,
      document_version: version,
      author: external_user,
      comment_type: :question,
      internal_only: false,
      body: "Can partners read this published version?"
    )
    create(
      :document_review_comment,
      document:,
      document_version: version,
      author: internal_user,
      comment_type: :request_change,
      internal_only: true,
      body: "Internal version review note"
    )

    sign_in_as(external_user)

    get document_version_path(version)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Can partners read this published version?")
    expect(response.body).not_to include("Internal version review note")
    expect(response.body).not_to include("社内レビューコメント")
  end

  it "rejects external document-level attempts to create internal-only review comments" do
    sign_in_as(external_user)

    expect do
      post project_document_document_review_comments_path(project, document), params: {
        document_review_comment: {
          comment_type: "request_change",
          internal_only: "1",
          body: "Please store this as an internal request."
        }
      }
    end.not_to change(DocumentReviewComment, :count)

    expect(response).to have_http_status(:forbidden)
    expect(DocumentReviewComment.where(body: "Please store this as an internal request.")).to be_empty
  end

  it "rejects external version-level attempts to create internal-only notes" do
    sign_in_as(external_user)

    expect do
      post document_version_document_review_comments_path(version), params: {
        document_review_comment: {
          comment_type: "note",
          internal_only: "1",
          body: "Please store this as an internal note."
        }
      }
    end.not_to change(DocumentReviewComment, :count)

    expect(response).to have_http_status(:forbidden)
    expect(DocumentReviewComment.where(body: "Please store this as an internal note.")).to be_empty
  end
end
