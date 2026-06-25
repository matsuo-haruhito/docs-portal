require "rails_helper"

RSpec.describe "Document bookmark pagination", type: :request do
  let(:company) { create(:company) }
  let(:project) { create(:project, name: "Visible Project") }
  let(:user) { create(:user, :external, company:) }

  before do
    create(:project_membership, project:, user:)
  end

  it "bounds saved favorites and read-later bookmarks with independent page params" do
    25.times do |index|
      create_bookmarked_document("Favorite Manual #{index + 1}", "favorite-manual-#{index + 1}", :favorite, index)
    end
    22.times do |index|
      create_bookmarked_document("Later Checklist #{index + 1}", "later-checklist-#{index + 1}", :read_later, index)
    end
    recent_document = create_readable_document("Recent Guide", "recent-guide")
    create(:access_log, user:, company:, project:, document: recent_document, action_type: :view, target_type: "document", accessed_at: Time.current)
    sign_in_as(user)

    get document_bookmarks_path, params: { favorite_page: 2, read_later_page: 1, recent_q: "recent" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("5 / 25件")
    expect(response.body).to include("21-25件目を表示")
    expect(response.body).to include("20 / 22件")
    expect(response.body).to include("1-20件目を表示")
    expect(response.body).to include("お気に入り 2 / 2 ページ")
    expect(response.body).to include("後で読む 1 / 2 ページ")
    expect(response.body).to include("Favorite Manual 1")
    expect(response.body).not_to include("Favorite Manual 25")
    expect(response.body).to include("Later Checklist 22")
    expect(response.body).not_to include("Later Checklist 1")
    expect(response.body).to include("recent_q=recent")
    expect(response.body).to include("favorite_page=1")
    expect(response.body).to include("read_later_page=1")
  end

  it "normalizes invalid and out-of-range saved bookmark pages without raising" do
    25.times do |index|
      create_bookmarked_document("Favorite Manual #{index + 1}", "favorite-manual-#{index + 1}", :favorite, index)
    end
    22.times do |index|
      create_bookmarked_document("Later Checklist #{index + 1}", "later-checklist-#{index + 1}", :read_later, index)
    end
    sign_in_as(user)

    get document_bookmarks_path, params: { favorite_page: "not-a-page", read_later_page: 999 }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("20 / 25件")
    expect(response.body).to include("1-20件目を表示")
    expect(response.body).to include("2 / 22件")
    expect(response.body).to include("21-22件目を表示")
    expect(response.body).to include("お気に入り 1 / 2 ページ")
    expect(response.body).to include("後で読む 2 / 2 ページ")
  end

  it "uses bookmark page params as the fallback after moving a saved bookmark" do
    document = create_readable_document("Manual", "manual")
    bookmark = create(:document_bookmark, user:, document:, bookmark_type: :read_later)
    sign_in_as(user)

    post move_to_favorite_document_bookmark_path(bookmark), params: {
      project_code: project.code,
      bookmark_q: "manual",
      recent_q: "guide",
      favorite_page: "2",
      read_later_page: "3"
    }

    expect(response).to redirect_to(
      document_bookmarks_path(
        project_code: project.code,
        bookmark_q: "manual",
        recent_q: "guide",
        favorite_page: "2",
        read_later_page: "3"
      )
    )
  end

  def create_bookmarked_document(title, slug, bookmark_type, index)
    document = create_readable_document(title, slug)
    create(:document_bookmark, user:, document:, bookmark_type:, created_at: (100 - index).minutes.ago)
  end

  def create_readable_document(title, slug)
    document = create(:document, project:, title:, slug:, visibility_policy: :restricted_external)
    create(:document_permission, document:, company:, access_level: :view)
    document
  end
end
