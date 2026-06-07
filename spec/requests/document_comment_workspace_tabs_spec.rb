require "rails_helper"

RSpec.describe "Document comment workspace tabs", type: :request do
  let(:internal_user) { create(:user, :internal) }
  let(:external_user) { create(:user, :external, company:) }
  let(:company) { create(:company) }
  let(:project) { create(:project, code: "COMMENTTAB", name: "Comment Tab Project") }
  let(:document) { create(:document, project:, title: "Comment Tab Manual", slug: "comment-tab-manual", visibility_policy: :restricted_external) }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0", status: :published) }

  before do
    document.update!(latest_version: version)
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document:, company:, access_level: :view)
  end

  it "restores an internal unresolved tab from the URL while preserving comment search" do
    create(
      :document_review_comment,
      document:,
      document_version: version,
      author: external_user,
      comment_type: :question,
      internal_only: false,
      body: "Release scope question should remain open"
    )
    create(
      :document_review_comment,
      document:,
      document_version: version,
      author: internal_user,
      comment_type: :request_change,
      internal_only: true,
      body: "Release scope internal check"
    )

    sign_in_as(internal_user)

    get project_document_path(project, document.slug, comment_q: "Release scope", comment_tab: "unresolved")

    expect(response).to have_http_status(:ok)
    html = Nokogiri::HTML(response.body)
    unresolved_input = html.at_css("#document-comment-tab-unresolved")
    qa_link = html.at_css("label[for='document-comment-tab-qa'] a")
    search_tab_input = html.at_css(".document-comment-search input[type='hidden'][name='comment_tab']")
    clear_link = html.css(".document-comment-search a[href]").find { |link| link.text.squish == "検索を解除" }

    expect(unresolved_input["checked"]).to be_present
    expect(qa_link["href"]).to include("comment_tab=qa")
    expect(qa_link["href"]).to include("comment_q=Release+scope")
    expect(search_tab_input["value"]).to eq("unresolved")
    expect(clear_link["href"]).to include("comment_tab=unresolved")
    expect(clear_link["href"]).not_to include("comment_q")
  end

  it "restores the Q&A tab on document version pages" do
    create(
      :document_review_comment,
      document:,
      document_version: version,
      author: external_user,
      comment_type: :question,
      internal_only: false,
      body: "Version scoped Q&A"
    )

    sign_in_as(internal_user)

    get document_version_path(version, comment_tab: "qa")

    expect(response).to have_http_status(:ok)
    html = Nokogiri::HTML(response.body)
    expect(html.at_css("#document-comment-tab-qa")["checked"]).to be_present
    expect(html.at_css("label[for='document-comment-tab-unresolved'] a")["href"]).to include("comment_tab=unresolved")
  end

  it "falls back to all for an external user when the internal review tab is requested" do
    create(
      :document_review_comment,
      document:,
      document_version: version,
      author: internal_user,
      comment_type: :request_change,
      internal_only: true,
      body: "Internal only review note"
    )

    sign_in_as(external_user)

    get project_document_path(project, document.slug, comment_tab: "review")

    expect(response).to have_http_status(:ok)
    html = Nokogiri::HTML(response.body)
    page_text = html.text
    search_tab_input = html.at_css(".document-comment-search input[type='hidden'][name='comment_tab']")

    expect(html.at_css("#document-comment-tab-all")["checked"]).to be_present
    expect(html.at_css("#document-comment-tab-review")).to be_nil
    expect(search_tab_input["value"]).to eq("all")
    expect(page_text).not_to include("確認事項")
    expect(page_text).not_to include("Internal only review note")
  end
end
