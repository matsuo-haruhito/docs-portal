require "rails_helper"

RSpec.describe "Document version manual upload actions", type: :request do
  let(:internal_user) { create(:user, :internal) }
  let(:external_user) { create(:user, :external) }
  let(:project) { create(:project) }
  let(:document) { create(:document, project:) }

  def manual_upload_version(status: :draft)
    create(
      :document_version,
      document:,
      status:,
      source_commit_hash: ManualDocumentUploadReview::MANUAL_UPLOAD_SOURCE,
      source_directory: "manual_uploads"
    )
  end

  it "redirects an invalid upload review decision back to the version with an alert" do
    version = manual_upload_version

    sign_in_as(internal_user)

    post document_version_upload_review_path(version), params: { decision: "hold" }

    expect(response).to redirect_to(document_version_path(version.public_id))
    expect(flash[:alert]).to eq("decision is invalid")
    expect(version.reload).to be_draft
  end

  it "forbids an external user from rolling back a viewable manual upload version" do
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document:, company: external_user.company, access_level: :view)
    version = manual_upload_version(status: :published)
    document.update!(latest_version: version)

    sign_in_as(external_user)

    post document_version_rollback_path(version)

    expect(response).to have_http_status(:forbidden)
    expect(version.reload).to be_published
    expect(document.reload.latest_version).to eq(version)
  end
end
