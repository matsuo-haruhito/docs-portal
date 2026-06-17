require "rails_helper"

RSpec.describe "Project AI context export scope cue", type: :request do
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

  def output_card
    parsed_html.xpath("//div[contains(concat(' ', normalize-space(@class), ' '), ' card ')][.//h2[normalize-space(.)='出力']]").first
  end

  def output_card_text
    output_card.text.squish
  end

  def output_card_link_href(label)
    output_card.css("a").find { _1.text.squish == label }["href"]
  end

  it "shows all scope and exported count next to export actions" do
    create_exportable_document(title: "Visible Manual", slug: "visible", body: "Visible body text.")
    create_exportable_document(title: "Operations Manual", slug: "operations", body: "Operations body text.")

    sign_in_as(external_user)

    get project_ai_context_path(project)

    expect(response).to have_http_status(:ok)
    expect(output_card_text).to include("現在の対象: 全件 / 出力対象: 2件")
    expect(output_card_text).to include("JSON / Markdown は現在の出力モード")
    expect(output_card_link_href("JSON を出力")).to include("mode=compact")
    expect(output_card_link_href("Markdown を出力")).to include("mode=compact")
  end

  it "shows selected scope and keeps selected document ids in export links" do
    selected = create_exportable_document(title: "Selected Manual", slug: "selected", body: "Selected body text.")
    internal = create_exportable_document(title: "Internal Note", slug: "internal", body: "Secret body text.", visibility_policy: :internal_only)
    create_exportable_document(title: "Other Manual", slug: "other", body: "Other body text.")

    sign_in_as(external_user)

    get project_ai_context_path(project, mode: :full, document_ids: [selected.id, internal.id])

    expect(response).to have_http_status(:ok)
    expect(output_card_text).to include("現在の対象: 選択中 / 選択ID: 2件 / 出力対象: 1件")
    expect(output_card_link_href("JSON を出力")).to include("mode=full", "document_ids%5B%5D=#{selected.id}")
    expect(output_card_link_href("Markdown を出力")).to include("mode=full", "document_ids%5B%5D=#{selected.id}")
  end

  it "keeps document search framed as a candidate filter in the export card" do
    create_exportable_document(title: "Setup Guide", slug: "setup-guide", body: "Setup guide body text.")
    create_exportable_document(title: "Operations Manual", slug: "operations", body: "Operations body text.")

    sign_in_as(external_user)

    get project_ai_context_path(project, document_q: "setup")

    expect(response).to have_http_status(:ok)
    expect(output_card_text).to include("現在の対象: 全件 / 出力対象: 2件")
    expect(output_card_text).to include("検索は候補の絞り込みです。JSON / Markdown は現在の対象範囲を出力します。")
  end
end
