require "rails_helper"

RSpec.describe "Document version quality checks", type: :request do
  let(:project) { create(:project) }
  let(:document) { create(:document, project:, title: "Manual", slug: "manual", visibility_policy: :restricted_external) }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0", status: :published, search_body_text: "internal_only") }
  let(:internal_user) { create(:user, :internal) }
  let(:external_user) { create(:user, :external, company: create(:company)) }

  def parsed_json
    JSON.parse(response.body)
  end

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
    payload = parsed_json
    expect(payload).to include(
      "valid" => false,
      "document_version" => a_hash_including(
        "public_id" => version.public_id,
        "version_label" => "v1.0.0",
        "status" => "published",
        "document" => a_hash_including(
          "public_id" => document.public_id,
          "title" => "Manual",
          "slug" => "manual",
          "visibility_policy" => "restricted_external"
        )
      ),
      "summary" => a_hash_including(
        "error_count" => 0,
        "warning_count" => 2,
        "info_count" => a_value >= 1
      )
    )
    expect(payload.fetch("checks")).to include(
      a_hash_including(
        "key" => "document_files",
        "severity" => "warning",
        "message" => "No document files are attached",
        "detail" => nil
      ),
      a_hash_including(
        "key" => "internal_only_text",
        "severity" => "warning",
        "message" => "Document contains internal-only wording"
      )
    )

    get document_version_quality_check_path(version, format: :md)
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/markdown")
    expect(response.body).to include("# Quality check: Manual")
    expect(response.body).to include("- version: v1.0.0")
    expect(response.body).to include("- result: fail")
    expect(response.body).to include("- warnings: 2")
    expect(response.body).to include("- **Warning** `document_files`: No document files are attached")
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

  it "forbids external users from html/json/markdown exports" do
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document:, company: external_user.company, access_level: :view)

    sign_in_as(external_user)

    [
      document_version_quality_check_path(version),
      document_version_quality_check_path(version, format: :json),
      document_version_quality_check_path(version, format: :md)
    ].each do |path|
      get path

      expect(response).to have_http_status(:forbidden)
    end
  end
end
