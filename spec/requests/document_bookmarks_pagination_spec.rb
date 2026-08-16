require "rails_helper"

RSpec.describe "Document bookmark pagination", type: :request do
  let(:company) { create(:company) }
  let(:project) { create(:project, name: "Visible Project") }
  let(:user) { create(:user, :external, company:) }

  before { create(:project_membership, project:, user:) }

  it "bounds each saved tab independently and keeps view on pager links" do
    25.times { |index| create_bookmarked_document("Favorite Manual #{index + 1}", "favorite-manual-#{index + 1}", :favorite, index) }
    22.times { |index| create_bookmarked_document("Later Checklist #{index + 1}", "later-checklist-#{index + 1}", :read_later, index) }
    sign_in_as(user)

    get document_bookmarks_path, params: { view: "favorite", favorite_page: 2, read_later_page: 1 }

    expect(response).to have_http_status(:ok)
    parsed_html = Nokogiri::HTML(response.body)
    expect(parsed_html.at_css(".list-footer__summary").text.squish).to eq("21–25 / 25件")
    expect(parsed_html.at_css(".list-footer__page-link.is-current").text.squish).to eq("2")
    expect(response.body).not_to include("Later Checklist")
    expect(parsed_html.css("nav.list-footer__pagination a").all? { _1["href"].include?("view=favorite") }).to be(true)

    get document_bookmarks_path, params: { view: "read_later", favorite_page: 2, read_later_page: 1 }

    parsed_html = Nokogiri::HTML(response.body)
    expect(parsed_html.at_css(".list-footer__summary").text.squish).to eq("1–20 / 22件")
    expect(parsed_html.at_css(".list-footer__page-link.is-current").text.squish).to eq("1")
    expect(response.body).not_to include("Favorite Manual")
    expect(parsed_html.css("nav.list-footer__pagination a").all? { _1["href"].include?("view=read_later") }).to be(true)
  end

  it "normalizes invalid and out-of-range page params per active tab" do
    25.times { |index| create_bookmarked_document("Favorite Manual #{index + 1}", "favorite-manual-#{index + 1}", :favorite, index) }
    sign_in_as(user)

    get document_bookmarks_path, params: { view: "favorite", favorite_page: 999 }

    expect(response).to have_http_status(:ok)
    parsed_html = Nokogiri::HTML(response.body)
    expect(parsed_html.at_css(".list-footer__summary").text.squish).to eq("21–25 / 25件")
    expect(parsed_html.at_css(".list-footer__page-link.is-current").text.squish).to eq("2")
  end

  it "uses view and page params as the fallback after moving a saved bookmark" do
    bookmark = create(:document_bookmark, user:, document: create_readable_document("Manual", "manual"), bookmark_type: :read_later)
    sign_in_as(user)

    post move_to_favorite_document_bookmark_path(bookmark), params: {
      view: "read_later", project_code: project.code, bookmark_q: "manual", recent_q: "guide", favorite_page: "2", read_later_page: "3"
    }

    expect(response).to redirect_to(document_bookmarks_path(
      view: "read_later", project_code: project.code, bookmark_q: "manual", recent_q: "guide", favorite_page: "2", read_later_page: "3"
    ))
  end

  def create_bookmarked_document(title, slug, bookmark_type, index)
    create(:document_bookmark, user:, document: create_readable_document(title, slug), bookmark_type:, created_at: (100 - index).minutes.ago)
  end

  def create_readable_document(title, slug)
    create(:document, project:, title:, slug:, visibility_policy: :restricted_external).tap do |document|
      create(:document_permission, document:, company:, access_level: :view)
    end
  end
end
