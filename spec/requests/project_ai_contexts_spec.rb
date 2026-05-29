require "rails_helper"

RSpec.describe "Project AI contexts", type: :request do
  let(:company) { create(:company) }
  let(:project) { create(:project, code: "AICTX", name: "AI Context Project") }
  let(:external_user) { create(:user, :external, company:, email_address: "client@example.com") }

  before do
    create(:project_membership, project:, user: external_user)
  end

  def create_exportable_document(title:, slug:, body:, visibility_policy: :restricted_external)
    document = create(:document, project:, title:, slug:, visibility_policy:)
    version = create(:document_version, document:, version_label: "v1", source_relative_path: "docs/#{slug}.md", search_body_text: body)
    document.update!(latest_version: version)
    create(:document_permission, document:, company:, access_level: :view) unless visibility_policy == :internal_only
    document
  end

  it "shows project AI context html and exports json/markdown for visible documents only" do
    visible = create_exportable_document(title: "Visible Manual", slug: "visible", body: "Visible body text.")
    create_exportable_document(title: "Internal Note", slug: "internal", body: "Secret body text.", visibility_policy: :internal_only)

    sign_in_as(external_user)

    get project_ai_context_path(project)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("AI向けコンテキスト")
    expect(response.body).to include("Visible Manual")
    expect(response.body).to include("Internal Note")

    get project_ai_context_path(project, format: :json, mode: :compact)
    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    expect(json.dig("summary", "document_count")).to eq(1)
    expect(json.fetch("documents").map { _1.fetch("public_id") }).to eq([visible.public_id])

    get project_ai_context_path(project, format: :md, mode: :full)
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/markdown")
    expect(response.body).to include("# Project: AI Context Project")
    expect(response.body).to include("Visible body text.")
    expect(response.body).not_to include("Secret body text.")
  end

  it "returns bad request for unsupported modes before exporting or logging access" do
    sign_in_as(external_user)

    expect do
      get project_ai_context_path(project, mode: "verbose")
      expect(response).to have_http_status(:bad_request)
      expect(response.body).to include("unsupported mode")

      get project_ai_context_path(project, format: :json, mode: "verbose")
      expect(response).to have_http_status(:bad_request)
      expect(JSON.parse(response.body)).to eq("error" => "unsupported mode")

      get project_ai_context_path(project, format: :md, mode: "verbose")
      expect(response).to have_http_status(:bad_request)
      expect(response.media_type).to eq("text/markdown")
      expect(response.body).to include("unsupported mode")
    end.not_to change(AccessLog.where(target_type: "ai_context"), :count)
  end

  it "records access logs for html and export responses" do
    create_exportable_document(title: "Visible Manual", slug: "visible", body: "Visible body text.")

    sign_in_as(external_user)

    expect do
      get project_ai_context_path(project)
      get project_ai_context_path(project, format: :json)
      get project_ai_context_path(project, format: :md)
    end.to change(AccessLog.where(target_type: "ai_context"), :count).by(3)
  end
end
