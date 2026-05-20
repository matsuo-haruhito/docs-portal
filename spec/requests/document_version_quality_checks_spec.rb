require "rails_helper"

RSpec.describe "Document version quality checks", type: :request do
  let(:project) { create(:project) }
  let(:document) { create(:document, project:, title: "Manual", slug: "manual", visibility_policy: :restricted_external) }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0", status: :published, search_body_text: "internal_only") }
  let(:internal_user) { create(:user, :internal) }
  let(:external_user) { create(:user, :external, company: create(:company)) }

  before do
    document.update!(latest_version: version)
  end

  it "shows the quality check to internal users in html/json/markdown" do
    sign_in_as(internal_user)

    get document_version_quality_check_path(version)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("品質チェック")
    expect(response.body).to include("internal_only_text")

    get document_version_quality_check_path(version, format: :json)
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/json")
    expect(JSON.parse(response.body).dig("document_version", "public_id")).to eq(version.public_id)

    get document_version_quality_check_path(version, format: :md)
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/markdown")
    expect(response.body).to include("# Quality check: Manual")
  end

  it "highlights preview quality checks in html" do
    version.assign_source_path_metadata!(source_path: "docs/manual.md", snapshot_kind: "received_markdown")
    version.mark_preview_build_queued!
    sign_in_as(internal_user)

    get document_version_quality_check_path(version)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Preview")
    expect(response.body).to include("Preview build is queued")
    expect(response.body).to include("Markdown preview site is not built yet")
    expect(response.body).to include("docs/manual.md")
  end

  it "forbids external users" do
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document:, company: external_user.company, access_level: :view)

    sign_in_as(external_user)

    get document_version_quality_check_path(version)
    expect(response).to have_http_status(:forbidden)
  end
end
