require "rails_helper"

RSpec.describe "Admin project permission previews", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "PREVIEW", name: "Preview Project") }
  let(:company) { create(:company, code: "ACME", name: "Acme") }
  let(:viewer) { create(:user, :external, company:, email_address: "viewer@example.com") }

  it "returns viewer and company level visible and downloadable diffs" do
    visible = create(:document, project:, title: "Visible", slug: "visible")
    downloadable = create(:document, project:, title: "Downloadable", slug: "downloadable")
    internal_only = create(:document, project:, title: "Internal", slug: "internal", visibility_policy: :internal_only)
    create(:project_membership, project:, user: viewer)
    create(:document_permission, document: visible, company:, access_level: :view)
    create(:document_permission, document: downloadable, company:, access_level: :view)

    sign_in_as(admin_user)

    get permission_preview_admin_project_path(project.code), params: {
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
      "code" => "ACME",
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

  it "forbids external users" do
    sign_in_as(create(:user, :external, company:))

    get permission_preview_admin_project_path(project.code), params: { company_ids: [company.id] }

    expect(response).to have_http_status(:forbidden)
  end
end
