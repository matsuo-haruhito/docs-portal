require "rails_helper"

RSpec.describe "Manual upload approval handoff", type: :request do
  let(:internal_user) { create(:user, :internal) }
  let(:external_user) { create(:user, :external) }
  let(:project) { create(:project, code: "UPLOAD-HANDOFF", name: "Upload Handoff Project") }
  let(:document) { create(:document, project:, title: "Upload Handoff Document", slug: "upload-handoff-document") }

  def create_manual_upload_version(status: :draft)
    create(
      :document_version,
      document:,
      version_label: "manual upload",
      status:,
      source_commit_hash: ManualDocumentUploadReview::MANUAL_UPLOAD_SOURCE
    )
  end

  it "shows a read-only version detail link after approving a manual upload" do
    version = create_manual_upload_version
    sign_in_as(internal_user)

    post document_version_upload_review_path(version), params: { decision: "approve" }
    follow_redirect!

    aggregate_failures do
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("取り消し可能な版詳細を開く")
      expect(response.body).to include(document_version_path(version))
    end
  end

  it "does not show the approval handoff on a normal document detail visit" do
    version = create_manual_upload_version(status: :published)
    document.update!(latest_version: version)
    sign_in_as(internal_user)

    get project_document_path(project, document.slug, version_id: version.public_id)

    aggregate_failures do
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("取り消し可能な版詳細を開く")
    end
  end

  it "does not expose the approval handoff to external users" do
    create(:project_membership, project:, user: external_user)
    create(:document_permission, :user_scoped, document:, user: external_user, access_level: :view)
    version = create_manual_upload_version(status: :published)
    document.update!(latest_version: version)
    sign_in_as(external_user)

    get project_document_path(project, document.slug, version_id: version.public_id)

    aggregate_failures do
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("取り消し可能な版詳細を開く")
    end
  end
end
