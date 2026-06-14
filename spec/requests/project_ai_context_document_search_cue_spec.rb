require "rails_helper"

RSpec.describe "Project AI context document search cue", type: :request do
  let(:company) { create(:company) }
  let(:project) { create(:project, code: "AICTX", name: "AI Context Project") }
  let(:external_user) { create(:user, :external, company:, email_address: "client@example.com") }

  before do
    create(:project_membership, project:, user: external_user)
  end

  def create_exportable_document(title:, slug:, body:)
    document = create(:document, project:, title:, slug:, visibility_policy: :restricted_external)
    version = create(:document_version, document:, version_label: "v1", source_relative_path: "docs/#{slug}.md", search_body_text: body)
    document.update!(latest_version: version)
    create(:document_permission, document:, company:, access_level: :view)
    document
  end

  it "shows the document query target and max length near the search field" do
    create_exportable_document(title: "Setup Guide", slug: "setup-guide", body: "Setup guide body text.")

    sign_in_as(external_user)

    get project_ai_context_path(project)

    expect(response).to have_http_status(:ok)
    page = Nokogiri::HTML(response.body)
    query_field = page.at_css('input[name="document_q"]')
    page_text = page.text.squish

    expect(query_field).to be_present
    expect(query_field["maxlength"]).to eq(ProjectAiContextsController::DOCUMENT_QUERY_MAX_LENGTH.to_s)
    expect(page_text).to include("文書名 / slug の一部一致で候補を絞り込みます。最大#{ProjectAiContextsController::DOCUMENT_QUERY_MAX_LENGTH}文字まで。")
    expect(page_text).to include("検索だけでは JSON / Markdown の対象範囲は変わらず、「選択した文書でpreview」後に反映されます。")
    expect(page_text).to include("検索後も、明示選択済みの文書は候補に残します。")
  end
end
