require "rails_helper"

RSpec.describe "Project AI contexts", type: :request do
  let(:company) { create(:company) }
  let(:project) { create(:project, code: "AICTX", name: "AI Context Project") }
  let(:external_user) { create(:user, :external, company:, email_address: "client@example.com") }

  before do
    create(:project_membership, project:, user: external_user)
  end

  def create_exportable_document(title:, slug:, body:, visibility_policy: :restricted_external, access_level: :view)
    document = create(:document, project:, title:, slug:, visibility_policy:)
    version = create(:document_version, document:, version_label: "v1", source_relative_path: "docs/#{slug}.md", search_body_text: body)
    document.update!(latest_version: version)
    create(:document_permission, document:, company:, access_level:) unless visibility_policy == :internal_only
    document
  end

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def ai_context_link_href(label)
    parsed_html.css("a").find { _1.text.squish == label }["href"]
  end

  it "shows project AI context html and exports json/markdown for visible documents only" do
    visible = create_exportable_document(title: "Visible Manual", slug: "visible", body: "Visible body text.")
    create_exportable_document(title: "Internal Note", slug: "internal", body: "Secret body text.", visibility_policy: :internal_only)

    sign_in_as(external_user)

    get project_ai_context_path(project)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("AI向けコンテキスト")
    expect(response.body).to include("現在の mode:")
    expect(response.body).to include("compact: summary と文書メタデータ中心")
    expect(response.body).to include("full: compact の内容に加えて本文テキストを含め")
    expect(response.body).to include("JSON / Markdown は現在の mode")
    expect(response.body).to include("対象文書を絞り込む")
    expect(response.body).to include("含まれる文書（export対象）")
    expect(response.body).to include("除外された文書（権限・公開状態の確認）")
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

  it "exports document file metadata without binary, signed urls, or hidden document leakage" do
    downloadable = create_exportable_document(
      title: "Downloadable Manual",
      slug: "downloadable",
      body: "Downloadable body text.",
      access_level: :download
    )
    view_only = create_exportable_document(title: "View Only Manual", slug: "view-only", body: "View only body text.")
    internal = create_exportable_document(title: "Internal Attachment Note", slug: "internal-attachment", body: "Secret body text.", visibility_policy: :internal_only)
    downloadable_file = create(
      :document_file,
      document_version: downloadable.latest_version,
      file_name: "requirements.pdf",
      content_type: "application/pdf",
      file_size: 12_345,
      scan_status: :scan_clean,
      storage_key: "spec/ai-context/requirements.pdf"
    )
    view_only_file = create(
      :document_file,
      document_version: view_only.latest_version,
      file_name: "diagram.png",
      content_type: "image/png",
      file_size: 2_048,
      scan_status: :scan_clean,
      storage_key: "spec/ai-context/diagram.png"
    )
    create(
      :document_file,
      document_version: internal.latest_version,
      file_name: "secret-plan.pdf",
      content_type: "application/pdf",
      file_size: 99,
      scan_status: :scan_clean,
      storage_key: "spec/ai-context/secret-plan.pdf"
    )

    sign_in_as(external_user)

    get project_ai_context_path(project, format: :json, mode: :compact)
    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    downloadable_json = json.fetch("documents").find { _1.fetch("public_id") == downloadable.public_id }
    view_only_json = json.fetch("documents").find { _1.fetch("public_id") == view_only.public_id }
    expect(downloadable_json.fetch("document_files")).to contain_exactly(
      a_hash_including(
        "public_id" => downloadable_file.public_id,
        "file_name" => "requirements.pdf",
        "content_type" => "application/pdf",
        "file_size" => 12_345,
        "scan_status" => "scan_clean",
        "downloadable" => true
      )
    )
    expect(view_only_json.fetch("document_files")).to contain_exactly(
      a_hash_including(
        "public_id" => view_only_file.public_id,
        "file_name" => "diagram.png",
        "content_type" => "image/png",
        "file_size" => 2_048,
        "scan_status" => "scan_clean",
        "downloadable" => false
      )
    )
    expect(response.body).not_to include("secret-plan.pdf", "spec/ai-context", "signed_id", "download_url")

    get project_ai_context_path(project, format: :md, mode: :full)
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/markdown")
    expect(response.body).to include("Attachments:")
    expect(response.body).to include("- requirements.pdf (content_type: application/pdf, size: 12345, scan_status: scan_clean, downloadable: true)")
    expect(response.body).to include("- diagram.png (content_type: image/png, size: 2048, scan_status: scan_clean, downloadable: false)")
    expect(response.body).not_to include("secret-plan.pdf", "spec/ai-context", "signed_id", "download_url")
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

  it "keeps selected document ids across preview and scoped exports" do
    selected = create_exportable_document(title: "Selected Manual", slug: "selected", body: "Selected body text.")
    other_visible = create_exportable_document(title: "Other Manual", slug: "other", body: "Other body text.")
    internal = create_exportable_document(title: "Internal Note", slug: "internal", body: "Secret body text.", visibility_policy: :internal_only)

    sign_in_as(external_user)

    get project_ai_context_path(project, mode: :full, document_ids: [selected.id])
    expect(response).to have_http_status(:ok)
    expect(page_text).to include("export対象:1 件")
    expect(page_text).to include("Selected Manual", "Other Manual")
    expect(ai_context_link_href("compact に切り替え")).to include("document_ids%5B%5D=#{selected.id}")
    expect(ai_context_link_href("full に切り替え")).to include("document_ids%5B%5D=#{selected.id}")
    expect(ai_context_link_href("JSON を出力")).to include("mode=full", "document_ids%5B%5D=#{selected.id}")
    expect(ai_context_link_href("Markdown を出力")).to include("mode=full", "document_ids%5B%5D=#{selected.id}")

    get project_ai_context_path(project, format: :json, mode: :compact, document_ids: [selected.id, internal.id])
    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    expect(json.dig("summary", "document_count")).to eq(1)
    expect(json.fetch("documents").map { _1.fetch("public_id") }).to eq([selected.public_id])

    get project_ai_context_path(project, format: :md, mode: :full, document_ids: [selected.id])
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Selected body text.")
    expect(response.body).not_to include("Other body text.", "Secret body text.")

    get project_ai_context_path(project, format: :json, mode: :compact)
    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    expect(json.dig("summary", "document_count")).to eq(2)
    expect(json.fetch("documents").map { _1.fetch("public_id") }).to contain_exactly(selected.public_id, other_visible.public_id)
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
