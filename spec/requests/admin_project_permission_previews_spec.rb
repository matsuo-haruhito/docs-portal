require "rails_helper"

RSpec.describe "Admin project permission previews", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "PREVIEW", name: "Preview Project") }
  let(:company) { create(:company, domain: "acme.example.com", name: "Acme") }
  let(:viewer) { create(:user, :external, company:, email_address: "viewer@example.com") }

  it "returns viewer and company level visible and downloadable diffs" do
    visible = create(:document, project:, title: "Visible", slug: "visible")
    downloadable = create(:document, project:, title: "Downloadable", slug: "downloadable")
    internal_only = create(:document, project:, title: "Internal", slug: "internal", visibility_policy: :internal_only)
    create(:project_membership, project:, user: viewer)
    create(:document_permission, document: visible, company:, access_level: :view)
    create(:document_permission, document: downloadable, company:, access_level: :view)

    sign_in_as(admin_user)

    expect(permission_preview_admin_project_path(project)).to eq("/admin/projects/PREVIEW/permission_preview")

    get permission_preview_admin_project_path(project), params: {
      company_ids: [company.id],
      grant_download_document_ids: [downloadable.id],
      revoke_document_ids: [visible.id],
      grant_document_ids: [internal_only.id]
    }

    expect(response).to have_http_status(:ok)

    body = response.parsed_body
    expect(body.dig("summary", "total_viewers")).to eq(1)
    expect(body.dig("summary", "changed_viewers")).to eq(1)
    expect(body.dig("summary", "gained_download_documents")).to eq(1)
    expect(body.dig("summary", "lost_documents")).to eq(1)

    company_summary = body.fetch("companies").first
    expect(company_summary).to include(
      "domain" => "acme.example.com",
      "changed_viewers" => 1,
      "gained_download_documents" => 1,
      "lost_documents" => 1
    )

    viewer_hash = body.fetch("viewers").first
    expect(viewer_hash).to include(
      "email_address" => "viewer@example.com",
      "before_visible_count" => 2,
      "after_visible_count" => 1,
      "before_downloadable_count" => 0,
      "after_downloadable_count" => 1
    )
    expect(viewer_hash.fetch("lost_documents").map { _1.fetch("title") }).to eq(["Visible"])
    expect(viewer_hash.fetch("gained_download_documents").map { _1.fetch("title") }).to eq(["Downloadable"])
    expect(viewer_hash.fetch("gained_documents")).to be_empty
  end

  it "does not persist membership or document permission changes while previewing" do
    visible = create(:document, project:, title: "Visible", slug: "visible")
    downloadable = create(:document, project:, title: "Downloadable", slug: "downloadable")
    internal_only = create(:document, project:, title: "Internal", slug: "internal", visibility_policy: :internal_only)
    membership = create(:project_membership, project:, user: viewer)
    view_permission = create(:document_permission, document: visible, company:, access_level: :view)
    download_permission = create(:document_permission, document: downloadable, company:, access_level: :download)
    membership_count = ProjectMembership.count
    permission_count = DocumentPermission.count

    sign_in_as(admin_user)

    get permission_preview_admin_project_path(project), params: {
      company_ids: [company.id],
      grant_document_ids: [internal_only.id],
      revoke_document_ids: [visible.id],
      grant_download_document_ids: [internal_only.id],
      revoke_download_document_ids: [downloadable.id],
      grant_project_membership: "1",
      revoke_project_membership: "1"
    }

    expect(response).to have_http_status(:ok)
    expect(ProjectMembership.count).to eq(membership_count)
    expect(DocumentPermission.count).to eq(permission_count)
    expect(membership.reload).to be_persisted
    expect(view_permission.reload).to have_attributes(access_level: "view")
    expect(download_permission.reload).to have_attributes(access_level: "download")
    expect(DocumentPermission.exists?(document: internal_only, company:)).to be(false)
  end

  it "deduplicates user and company viewers while ignoring invalid ids and inactive users" do
    company_peer = create(:user, :external, company:, email_address: "peer@example.com")
    direct_user = create(:user, :external, email_address: "direct@example.com")
    inactive_company_user = create(:user, :external, company:, email_address: "inactive-company@example.com", active: false)
    inactive_direct_user = create(:user, :external, email_address: "inactive-direct@example.com", active: false)

    sign_in_as(admin_user)

    get permission_preview_admin_project_path(project), params: {
      company_ids: [company.id, "", "not-a-company"],
      user_ids: [viewer.id, direct_user.id, inactive_direct_user.id, "", "not-a-user"]
    }

    expect(response).to have_http_status(:ok)

    body = response.parsed_body
    viewer_emails = body.fetch("viewers").map { _1.fetch("email_address") }

    expect(body.dig("summary", "total_viewers")).to eq(3)
    expect(viewer_emails).to contain_exactly("direct@example.com", "peer@example.com", "viewer@example.com")
    expect(viewer_emails).not_to include(
      "inactive-company@example.com",
      "inactive-direct@example.com",
      "not-a-user",
      "not-a-company"
    )
    expect(inactive_company_user).not_to be_active
    expect(inactive_direct_user).not_to be_active
  end

  it "keeps empty and invalid viewer params as an empty preview" do
    sign_in_as(admin_user)

    get permission_preview_admin_project_path(project), params: {
      company_ids: ["", "missing-company"],
      user_ids: ["", "missing-user"]
    }

    expect(response).to have_http_status(:ok)

    body = response.parsed_body
    expect(body.dig("summary", "total_viewers")).to eq(0)
    expect(body.dig("summary", "changed_viewers")).to eq(0)
    expect(body.fetch("viewers")).to be_empty
    expect(body.fetch("companies")).to be_empty
  end

  it "forbids external users" do
    sign_in_as(create(:user, :external, company:))

    get permission_preview_admin_project_path(project), params: { company_ids: [company.id] }

    expect(response).to have_http_status(:forbidden)
  end
end
