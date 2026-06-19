require "rails_helper"

RSpec.describe "Document comment workspace empty search", type: :request do
  let(:internal_user) { create(:user, :internal) }
  let(:company) { create(:company) }
  let(:external_user) { create(:user, :external, company:) }
  let(:project) { create(:project, code: "REVIEW", name: "Review Project") }
  let(:document) { create(:document, project:, title: "Review Manual", slug: "review-manual", visibility_policy: :restricted_external) }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0", status: :published) }

  before do
    document.update!(latest_version: version)
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document:, company:, access_level: :view)
  end

  def clear_search_link(html, panel_selector)
    html.at_css(panel_selector).css("a").find { |node| node.text.squish == "検索を解除してすべて表示" }
  end

  def parsed_query(href)
    Rack::Utils.parse_nested_query(URI.parse(href).query)
  end

  it "lets internal users clear an empty review search while keeping the current tab context" do
    create(
      :document_review_comment,
      document:,
      document_version: version,
      author: internal_user,
      comment_type: :request_change,
      internal_only: true,
      body: "Visible internal review item",
      source_path: "docs/review-note.md"
    )

    sign_in_as(internal_user)

    get project_document_path(project, document.slug, comment_tab: "review", comment_q: "no matching review", page: "2")

    expect(response).to have_http_status(:ok)
    html = Nokogiri::HTML(response.body)
    review_panel = html.at_css(".document-comment-tabs__panel--review")
    link = clear_search_link(html, ".document-comment-tabs__panel--review")

    expect(review_panel.text).to include("検索条件に一致する確認事項はありません")
    expect(link).to be_present
    expect(URI.parse(link["href"]).path).to eq(project_document_path(project, document.slug))
    expect(parsed_query(link["href"])).to eq("page" => "2", "comment_tab" => "review")
  end

  it "keeps external empty-search recovery scoped to public Q&A without internal-only wording" do
    create(
      :document_review_comment,
      document:,
      document_version: version,
      author: internal_user,
      comment_type: :request_change,
      internal_only: true,
      body: "Private review escalation",
      source_path: "docs/private-review.md"
    )

    sign_in_as(external_user)

    get project_document_path(project, document.slug, comment_tab: "unresolved", comment_q: "private-review")

    expect(response).to have_http_status(:ok)
    html = Nokogiri::HTML(response.body)
    page_text = html.text.squish
    unresolved_panel = html.at_css(".document-comment-tabs__panel--unresolved")
    link = clear_search_link(html, ".document-comment-tabs__panel--unresolved")

    expect(unresolved_panel.text).to include("検索条件に一致する未解決のコメントはありません")
    expect(link).to be_present
    expect(URI.parse(link["href"]).path).to eq(project_document_path(project, document.slug))
    expect(parsed_query(link["href"])).to eq("comment_tab" => "unresolved")
    expect(page_text).not_to include("確認事項")
    expect(page_text).not_to include("内部限定")
    expect(page_text).not_to include("Private review escalation")
    expect(page_text).not_to include("docs/private-review.md")
  end
end
