require "rails_helper"

RSpec.describe "Document bookmark filter contract", type: :request do
  let(:company) { create(:company) }
  let(:project) { create(:project, name: "Visible Project") }
  let(:user) { create(:user, :external, company:) }

  before { create(:project_membership, project:, user:) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def readable_document(title:, slug:)
    create(:document, project:, title:, slug:, visibility_policy: :restricted_external).tap do |document|
      create(:document_permission, document:, company:, access_level: :view)
    end
  end

  it "normalizes oversized recent queries and preserves recent view" do
    recent_document = readable_document(title: "Recent Guide", slug: "recent-guide")
    create(:access_log, user:, company:, project:, document: recent_document, action_type: :view, target_type: "document", accessed_at: Time.current)
    raw_query = "  #{'recent-query-' * 12}overflow  "
    normalized_query = raw_query.strip.slice(0, DocumentBookmarksController::BOOKMARK_QUERY_MAX_LENGTH)
    sign_in_as(user)

    get document_bookmarks_path, params: { view: "recent", recent_q: raw_query }

    input = parsed_html.at_css("input[name='recent_q'][type='search']")
    expect(input["value"]).to eq(normalized_query)
    expect(input["maxlength"]).to eq(DocumentBookmarksController::BOOKMARK_QUERY_MAX_LENGTH.to_s)
    expect(parsed_html.at_css("input[type='hidden'][name='view'][value='recent']")).to be_present
  end

  it "keeps bookmark query scoped to saved tabs and recent query scoped to recent" do
    saved = readable_document(title: "Saved Manual", slug: "saved-manual")
    recent_match = readable_document(title: "Recent Beta Guide", slug: "recent-beta-guide")
    recent_miss = readable_document(title: "Recent Operations Guide", slug: "recent-operations-guide")
    create(:document_bookmark, user:, document: saved, bookmark_type: :favorite)
    create(:access_log, user:, company:, project:, document: recent_match, action_type: :view, target_type: "document", accessed_at: 2.minutes.ago)
    create(:access_log, user:, company:, project:, document: recent_miss, action_type: :view, target_type: "document", accessed_at: 1.minute.ago)
    sign_in_as(user)

    get document_bookmarks_path, params: { view: "favorite", bookmark_q: "manual", recent_q: "beta" }
    expect(response.body).to include("Saved Manual")
    expect(response.body).not_to include("Recent Beta Guide", "Recent Operations Guide")

    get document_bookmarks_path, params: { view: "recent", bookmark_q: "manual", recent_q: "beta" }
    expect(response.body).to include("Recent Beta Guide")
    expect(response.body).not_to include("Saved Manual", "Recent Operations Guide")
  end
end
