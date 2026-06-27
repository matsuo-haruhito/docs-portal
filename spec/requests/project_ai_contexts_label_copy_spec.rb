require "rails_helper"

RSpec.describe "Project AI context label copy", type: :request do
  let(:company) { create(:company) }
  let(:project) { create(:project, code: "AICTX", name: "AI Context Project") }
  let(:external_user) { create(:user, :external, company:, email_address: "client@example.com") }

  before do
    create(:project_membership, project:, user: external_user)
  end

  def create_exportable_document(title:, slug:, body:, visibility_policy: :restricted_external, project: self.project)
    document = create(:document, project:, title:, slug:, visibility_policy:)
    version = create(:document_version, document:, version_label: "v1", source_relative_path: "docs/#{slug}.md", search_body_text: body)
    document.update!(latest_version: version)
    create(:document_permission, document:, company:, access_level: :view) unless visibility_policy == :internal_only
    document
  end

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  it "shows Japanese labels for output mode and selected scope without changing raw export identifiers" do
    selected = create_exportable_document(title: "Selected Manual", slug: "selected", body: "Selected body text.")
    internal = create_exportable_document(title: "Internal Note", slug: "internal", body: "Secret body text.", visibility_policy: :internal_only)
    other_project = create(:project, code: "OTHERCTX", name: "Other Context Project")
    outside_project_document = create_exportable_document(
      title: "Outside Project Manual",
      slug: "outside-project",
      body: "Outside project body text.",
      project: other_project
    )
    missing_document_id = Document.maximum(:id) + 100

    sign_in_as(external_user)

    get project_ai_context_path(project, mode: :full, document_ids: [selected.id, internal.id, outside_project_document.id, missing_document_id])

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("AI向けコンテキスト")
    expect(page_text).to include("出力モードID / mode: full")
    expect(page_text).to include("選択範囲の引き継ぎ")
    expect(page_text).to include("出力モード: 本文込み / 出力モードID / mode: full / 範囲: 選択中")
    expect(page_text).to include("document_q は候補検索のみです。JSON / Markdown の対象範囲は、この選択範囲と閲覧権限で決まります。")
    expect(parsed_html.css("th").map { _1.text.squish }).to include("公開ID")
    expect(page_text).not_to include("選択 scope handoff")
    expect(page_text).not_to include("scope: selected")
  end
end
