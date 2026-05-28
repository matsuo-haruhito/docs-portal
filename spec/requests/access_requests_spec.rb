require "rails_helper"

RSpec.describe "Access requests", type: :request do
  let(:company) { create(:company) }
  let(:user) { create(:user, :external, company:) }
  let(:other_user) { create(:user, :external, company:) }
  let(:project) { create(:project, code: "REQ", name: "Request Project") }
  let(:document) { create(:document, project:, title: "Manual", slug: "manual", visibility_policy: :restricted_external) }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0", status: :published) }
  let(:file) { create(:document_file, document_version: version, file_name: "manual.pdf", content_type: "application/pdf", file_size: 10) }

  before do
    document.update!(latest_version: version)
    create(:project_membership, project:, user:)
    create(:project_membership, project:, user: other_user)
    create(:document_permission, document:, company:, access_level: :view)
  end

  it "creates a download access request for a visible document file" do
    sign_in_as(user)

    expect do
      post access_requests_path, params: {
        requestable_type: "DocumentFile",
        requestable_public_id: file.public_id,
        requested_access_level: "download"
      }
    end.to change(AccessRequest, :count).by(1)

    expect(response).to redirect_to(access_requests_path)
    request = AccessRequest.order(:id).last
    expect(request.requester).to eq(user)
    expect(request.requestable).to eq(file)
    expect(request).to be_pending
    expect(request.reason).to include("manual.pdf")
  end

  it "stores and displays japanese default reasons for project, document, and file requests" do
    sign_in_as(user)

    post access_requests_path, params: {
      requestable_type: "Project",
      requestable_public_id: project.code,
      requested_access_level: "manage"
    }
    expect(AccessRequest.order(:id).last.reason).to eq("案件「Request Project」に管理権限が必要です。")

    post access_requests_path, params: {
      requestable_type: "Document",
      requestable_public_id: document.public_id,
      requested_access_level: "download"
    }
    expect(AccessRequest.order(:id).last.reason).to eq("文書「Manual」にダウンロード権限が必要です。")

    post access_requests_path, params: {
      requestable_type: "DocumentFile",
      requestable_public_id: file.public_id,
      requested_access_level: "download"
    }
    expect(AccessRequest.order(:id).last.reason).to eq("ファイル「manual.pdf」にダウンロード権限が必要です。")

    get access_requests_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("案件「Request Project」に管理権限が必要です。")
    expect(response.body).to include("文書「Manual」にダウンロード権限が必要です。")
    expect(response.body).to include("ファイル「manual.pdf」にダウンロード権限が必要です。")
    expect(response.body).not_to include("Need ")
  end

  it "does not duplicate the same pending request" do
    sign_in_as(user)
    create(:access_request, requester: user, requestable: file, requested_access_level: :download)

    expect do
      post access_requests_path, params: {
        requestable_type: "DocumentFile",
        requestable_public_id: file.public_id,
        requested_access_level: "download"
      }
    end.not_to change(AccessRequest, :count)

    expect(response).to redirect_to(access_requests_path)
  end

  it "lists and cancels only the current user's requests" do
    own_request = create(:access_request, requester: user, requestable: file, requested_access_level: :download)
    other_request = create(:access_request, requester: other_user, requestable: document, requested_access_level: :download, reason: "Other user request")

    sign_in_as(user)

    get access_requests_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("manual.pdf")
    expect(response.body).not_to include(other_request.reason)

    post cancel_access_request_path(own_request)

    expect(response).to redirect_to(access_requests_path)
    expect(own_request.reload).to be_cancelled
  end

  it "shows request buttons on the version page when download is not allowed" do
    sign_in_as(user)

    get document_version_path(version)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("ダウンロード権限を申請")
    expect(response.body).to include("申請")
  end
end
