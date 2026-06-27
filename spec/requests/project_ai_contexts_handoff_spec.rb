require "rails_helper"

RSpec.describe "Project AI context selected scope handoff", type: :request do
  let(:company) { create(:company) }
  let(:project) { create(:project, code: "AIHANDOFF", name: "AI Handoff Project") }
  let(:external_user) { create(:user, :external, company:, email_address: "client@example.com") }

  before do
    create(:project_membership, project:, user: external_user)
  end

  def create_exportable_document(title:, slug:, body:, visibility_policy: :restricted_external, access_level: :view, project: self.project)
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

  it "shows a read-only handoff summary for visible selected documents only" do
    selected = create_exportable_document(title: "Selected Handoff Manual", slug: "selected-handoff", body: "Selected body text.")
    other_visible = create_exportable_document(title: "Other Visible Manual", slug: "other-visible", body: "Other body text.")
    internal = create_exportable_document(title: "Internal Handoff Note", slug: "internal-handoff", body: "Secret body text.", visibility_policy: :internal_only)
    other_project = create(:project, code: "OTHERHANDOFF", name: "Other Handoff Project")
    outside_project_document = create_exportable_document(
      title: "Outside Handoff Manual",
      slug: "outside-handoff",
      body: "Outside project body text.",
      project: other_project
    )
    missing_document_id = Document.maximum(:id) + 100

    sign_in_as(external_user)

    get project_ai_context_path(
      project,
      mode: :full,
      document_q: "other",
      document_ids: [selected.id, internal.id, outside_project_document.id, missing_document_id]
    )

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("選択範囲の引き継ぎ")
    expect(page_text).to include("出力モード: 本文込み / 出力モードID / mode: full / 範囲: 選択中 / 選択ID: 4件 / 案件内候補: 2件 / 出力対象: 1件 / 候補外: 2件")
    expect(page_text).to include("document_q は候補検索のみです。JSON / Markdown の対象範囲は、この選択範囲と閲覧権限で決まります。")
    expect(page_text).to include("Selected Handoff Manual")
    expect(page_text).to include("selected-handoff")
    expect(page_text).to include(selected.public_id)
    expect(page_text).not_to include(outside_project_document.title, outside_project_document.public_id, internal.public_id, missing_document_id.to_s)

    get project_ai_context_path(
      project,
      format: :json,
      mode: :compact,
      document_q: "other",
      document_ids: [selected.id, internal.id, outside_project_document.id, missing_document_id]
    )
    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    expect(json.dig("summary", "document_count")).to eq(1)
    expect(json.fetch("documents").map { _1.fetch("public_id") }).to eq([selected.public_id])

    get project_ai_context_path(project, format: :json, mode: :compact, document_q: "other")
    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    expect(json.dig("summary", "document_count")).to eq(2)
    expect(json.fetch("documents").map { _1.fetch("public_id") }).to contain_exactly(selected.public_id, other_visible.public_id)
  end
end
