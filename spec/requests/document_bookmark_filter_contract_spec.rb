require "rails_helper"

RSpec.describe "Document bookmark filter contract", type: :request do
  let(:company) { create(:company) }
  let(:project) { create(:project, name: "Visible Project") }
  let(:user) { create(:user, :external, company:) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def input_value(name:, type: nil)
    selector = type ? "input[name='#{name}'][type='#{type}']" : "input[name='#{name}']"
    parsed_html.at_css(selector)&.[]("value")
  end

  def input_attribute(name:, attribute:, type: nil)
    selector = type ? "input[name='#{name}'][type='#{type}']" : "input[name='#{name}']"
    parsed_html.at_css(selector)&.[](attribute)
  end

  def link_href(text)
    parsed_html.css("a[href]").find { |node| node.text.strip == text }&.[]("href")
  end

  def readable_document(title:, slug:, document_project: project)
    create(:project_membership, project: document_project, user:)
    create(:document, project: document_project, title:, slug:, visibility_policy: :restricted_external).tap do |document|
      create(:document_permission, document:, company:, access_level: :view)
    end
  end

  def record_recent_view(document, accessed_at: Time.current)
    create(
      :access_log,
      user:,
      company:,
      project: document.project,
      document:,
      action_type: :view,
      target_type: "document",
      accessed_at:
    )
  end

  before do
    create(:project_membership, project:, user:)
  end

  it "normalizes oversized recent document queries before rendering controls and preserved fields" do
    recent_document = readable_document(title: "Recent Guide", slug: "recent-guide")
    record_recent_view(recent_document)
    create(:document_bookmark, user:, document: readable_document(title: "Saved Manual", slug: "saved-manual"), bookmark_type: :favorite)
    raw_recent_query = "  #{'recent-query-' * 12}overflow  "
    normalized_recent_query = raw_recent_query.strip.slice(0, DocumentBookmarksController::BOOKMARK_QUERY_MAX_LENGTH)
    sign_in_as(user)

    get document_bookmarks_path, params: {
      project_code: project.code,
      bookmark_q: "saved",
      recent_q: raw_recent_query
    }

    expect(response).to have_http_status(:ok)
    expect(input_value(name: "recent_q", type: "search")).to eq(normalized_recent_query)
    expect(input_attribute(name: "recent_q", attribute: "maxlength", type: "search")).to eq(DocumentBookmarksController::BOOKMARK_QUERY_MAX_LENGTH.to_s)
    expect(input_value(name: "recent_q", type: "hidden")).to eq(normalized_recent_query)
    expect(response.body).to include("最近見た文書検索「#{normalized_recent_query}」")
    expect(response.body).not_to include(raw_recent_query.strip)

    clear_href = link_href("最近見た条件をクリア")
    expect(clear_href).to include("project_code=#{project.code}")
    expect(clear_href).to include("bookmark_q=saved")
    expect(clear_href).not_to include("recent_q")
  end

  it "keeps saved bookmark filters in the recent form while preserving recent search in the saved form" do
    recent_document = readable_document(title: "Recent Manual", slug: "recent-manual")
    record_recent_view(recent_document)
    create(:document_bookmark, user:, document: readable_document(title: "Saved Manual", slug: "saved-manual"), bookmark_type: :favorite)
    sign_in_as(user)

    get document_bookmarks_path, params: {
      project_code: project.code,
      bookmark_q: "manual",
      recent_q: "recent"
    }

    expect(response).to have_http_status(:ok)
    expect(input_value(name: "recent_q", type: "hidden")).to eq("recent")
    expect(input_value(name: "project_code", type: "hidden")).to eq(project.code)
    expect(input_value(name: "bookmark_q", type: "hidden")).to eq("manual")
  end

  it "keeps bookmark query scoped to saved shortcuts and recent query scoped to recent documents" do
    saved_document = readable_document(title: "Saved Manual", slug: "saved-manual")
    later_document = readable_document(title: "Saved Checklist", slug: "saved-checklist")
    recent_match = readable_document(title: "Recent Beta Guide", slug: "recent-beta-guide")
    recent_miss = readable_document(title: "Recent Operations Guide", slug: "recent-operations-guide")
    create(:document_bookmark, user:, document: saved_document, bookmark_type: :favorite)
    create(:document_bookmark, user:, document: later_document, bookmark_type: :read_later)
    record_recent_view(recent_match, accessed_at: 2.minutes.ago)
    record_recent_view(recent_miss, accessed_at: 1.minute.ago)
    sign_in_as(user)

    get document_bookmarks_path, params: { bookmark_q: "manual" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Saved Manual")
    expect(response.body).not_to include("Saved Checklist")
    expect(response.body).to include("Recent Beta Guide")
    expect(response.body).to include("Recent Operations Guide")

    get document_bookmarks_path, params: { recent_q: "beta" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Saved Manual")
    expect(response.body).to include("Saved Checklist")
    expect(response.body).to include("Recent Beta Guide")
    expect(response.body).not_to include("Recent Operations Guide")
  end
end
