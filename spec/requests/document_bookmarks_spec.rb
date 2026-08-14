require "rails_helper"

RSpec.describe "Document bookmarks", type: :request do
  let(:company) { create(:company) }
  let(:project) { create(:project, name: "Visible Project") }
  let(:user) { create(:user, :external, company:) }
  let(:document) { create(:document, project:, title: "Manual", slug: "manual", visibility_policy: :restricted_external) }

  before do
    create(:project_membership, project:, user:)
    create(:document_permission, document:, company:, access_level: :view)
  end

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def create_readable_document(title, slug)
    create(:document, project:, title:, slug:, visibility_policy: :restricted_external).tap do |record|
      create(:document_permission, document: record, company:, access_level: :view)
    end
  end

  def expect_server_rendered_tab_contract(active_tab_id:, active_panel_id:)
    tablist = parsed_html.at_css("nav[role='tablist']")
    tabs = tablist.css("[role='tab']")
    active_tab = parsed_html.at_css("##{active_tab_id}")
    expected_controls = {
      "favorite-tab" => "favorite-bookmarks",
      "read-later-tab" => "read-later-bookmarks",
      "recent-tab" => "recent-documents"
    }
    inactive_panel_ids = expected_controls.values - [active_panel_id]

    expect(tablist["data-controller"].to_s.split).to include("server-rendered-tabs")
    expect(tabs.size).to eq(3)
    expect(tabs.to_h { |tab| [tab["id"], tab["aria-controls"]] }).to eq(expected_controls)
    expect(tabs).to all(satisfy { _1["data-server-rendered-tabs-target"] == "tab" })
    expect(tabs).to all(satisfy { _1["data-action"].to_s.split.include?("keydown->server-rendered-tabs#keydown") })
    expect(active_tab["aria-selected"]).to eq("true")
    expect(active_tab["tabindex"]).to eq("0")
    expect(tabs.reject { _1["id"] == active_tab_id }.map { _1["tabindex"] }.uniq).to eq(["-1"])
    expect(parsed_html.at_css("##{active_panel_id}[role='tabpanel'][aria-labelledby='#{active_tab_id}']")).to be_present
    inactive_panel_ids.each { |panel_id| expect(parsed_html.at_css("##{panel_id}")).to be_nil }
  end

  it "renders only the favorite panel by default with accessible tab relationships" do
    later_document = create_readable_document("Checklist", "checklist")
    recent_document = create_readable_document("Guide", "guide")
    create(:document_bookmark, user:, document:, bookmark_type: :favorite)
    create(:document_bookmark, user:, document: later_document, bookmark_type: :read_later)
    create(:access_log, user:, company:, project:, document: recent_document, action_type: :view, target_type: "document", accessed_at: Time.current)
    sign_in_as(user)

    get document_bookmarks_path

    expect(response).to have_http_status(:ok)
    expect_server_rendered_tab_contract(active_tab_id: "favorite-tab", active_panel_id: "favorite-bookmarks")
    expect(parsed_html.at_css("#read-later-bookmarks")).to be_nil
    expect(parsed_html.at_css("#recent-documents")).to be_nil
    expect(parsed_html.at_css("section.bookmark-filter h2.bookmark-filter__heading").text.squish).to eq("絞り込み")
    expect(parsed_html.css("#favorite-bookmarks .resource-list__item .badge")).to be_empty
    expect(response.body).to include("Manual")
    expect(response.body).not_to include("Checklist", "Guide", "対象: お気に入り", "よく開く文書")
  end

  it "renders only the panel selected by an allowed view" do
    later_document = create_readable_document("Checklist", "checklist")
    recent_document = create_readable_document("Guide", "guide")
    create(:document_bookmark, user:, document:, bookmark_type: :favorite)
    create(:document_bookmark, user:, document: later_document, bookmark_type: :read_later)
    create(:access_log, user:, company:, project:, document: recent_document, action_type: :view, target_type: "document", accessed_at: Time.current)
    sign_in_as(user)

    get document_bookmarks_path, params: { view: "read_later" }
    expect_server_rendered_tab_contract(active_tab_id: "read-later-tab", active_panel_id: "read-later-bookmarks")
    expect(parsed_html.at_css("#read-later-bookmarks[role='tabpanel']")).to be_present
    expect(parsed_html.at_css("#favorite-bookmarks, #recent-documents")).to be_nil
    expect(parsed_html.css("#read-later-bookmarks .resource-list__item .badge")).to be_empty
    expect(response.body).to include("Checklist")
    expect(response.body).not_to include("Manual", "Guide", "対象: 後で読む", "あとで確認")

    get document_bookmarks_path, params: { view: "recent" }
    expect_server_rendered_tab_contract(active_tab_id: "recent-tab", active_panel_id: "recent-documents")
    expect(parsed_html.at_css("#recent-documents[role='tabpanel']")).to be_present
    expect(parsed_html.at_css("#favorite-bookmarks, #read-later-bookmarks")).to be_nil
    expect(parsed_html.at_css("#recent-documents h3.bookmark-filter__heading").text.squish).to eq("絞り込み")
    recent_limit_tooltip = parsed_html.at_css("#recent-documents .info-tooltip[role]") || parsed_html.at_css("#recent-documents .info-tooltip")
    expect(recent_limit_tooltip).to be_present
    expect(recent_limit_tooltip["aria-label"]).to eq("最近表示された文書を最大20件表示します。")
    expect(parsed_html.css("#recent-documents .resource-list__item .badge")).to be_empty
    expect(response.body).to include("Guide")
    expect(response.body).not_to include("Manual", "Checklist", "対象: 最近見た文書")
  end

  it "normalizes an unsupported view to favorite" do
    create(:document_bookmark, user:, document:, bookmark_type: :favorite)
    sign_in_as(user)

    get document_bookmarks_path, params: { view: "unsupported" }

    expect(response).to have_http_status(:ok)
    expect(parsed_html.at_css("#favorite-tab[aria-selected='true']")).to be_present
    expect(parsed_html.at_css("#favorite-bookmarks[role='tabpanel']")).to be_present
  end

  it "filters the selected saved bookmark panel and preserves view in the form" do
    other_document = create_readable_document("Checklist", "checklist")
    create(:document_bookmark, user:, document:, bookmark_type: :favorite)
    create(:document_bookmark, user:, document: other_document, bookmark_type: :favorite)
    sign_in_as(user)

    get document_bookmarks_path, params: { view: "favorite", bookmark_q: "manual" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Manual")
    expect(response.body).not_to include("Checklist")
    expect(parsed_html.at_css("form input[type='hidden'][name='view'][value='favorite']")).to be_present
  end

  it "filters recent documents without rendering saved bookmark panels" do
    matching = create_readable_document("Beta Guide", "beta-guide")
    other = create_readable_document("Operations Guide", "operations-guide")
    create(:access_log, user:, company:, project:, document: matching, action_type: :view, target_type: "document", accessed_at: 2.minutes.ago)
    create(:access_log, user:, company:, project:, document: other, action_type: :view, target_type: "document", accessed_at: 1.minute.ago)
    sign_in_as(user)

    get document_bookmarks_path, params: { view: "recent", recent_q: "beta" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Beta Guide")
    expect(response.body).not_to include("Operations Guide")
    expect(parsed_html.at_css("#recent-documents form input[type='hidden'][name='view'][value='recent']")).to be_present
    expect(parsed_html.at_css("#favorite-bookmarks, #read-later-bookmarks")).to be_nil
  end

  it "does not list bookmarks for documents no longer readable by the current user" do
    hidden_document = create(:document, title: "Hidden Manual", slug: "hidden-manual", visibility_policy: :restricted_external)
    create(:document_bookmark, user:, document:, bookmark_type: :favorite)
    create(:document_bookmark, user:, document: hidden_document, bookmark_type: :favorite)
    sign_in_as(user)

    get document_bookmarks_path, params: { view: "favorite" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Manual")
    expect(response.body).not_to include("Hidden Manual")
  end

  it "creates a favorite bookmark" do
    sign_in_as(user)

    expect do
      post document_bookmarks_path, params: { document_bookmark: { document_id: document.public_id, bookmark_type: "favorite" } }
    end.to change(DocumentBookmark.favorite, :count).by(1)

    expect(response).to redirect_to(root_path)
  end

  it "creates a read-later bookmark" do
    sign_in_as(user)

    expect do
      post document_bookmarks_path, params: { document_bookmark: { document_id: document.public_id, bookmark_type: "read_later" } }
    end.to change(DocumentBookmark.read_later, :count).by(1)
  end

  it "falls back to favorite when bookmark_type is invalid" do
    sign_in_as(user)

    expect do
      post document_bookmarks_path, params: { document_bookmark: { document_id: document.public_id, bookmark_type: "unexpected" } }
    end.to change(DocumentBookmark.favorite, :count).by(1)

    expect(user.document_bookmarks.sole).to be_favorite
  end

  it "moves a read-later bookmark to favorites and returns to the active view" do
    bookmark = create(:document_bookmark, user:, document:, bookmark_type: :read_later)
    sign_in_as(user)

    expect do
      post move_to_favorite_document_bookmark_path(bookmark), params: { view: "read_later" }
    end.to change(DocumentBookmark.favorite, :count).by(1)
      .and change(DocumentBookmark.read_later, :count).by(-1)

    expect(user.document_bookmarks.favorite.where(document:).exists?).to be(true)
    expect(DocumentBookmark.exists?(bookmark.id)).to be(false)
    expect(response).to redirect_to(document_bookmarks_path(view: "read_later"))
    expect(flash[:notice]).to be_present
  end

  it "moves a read-later bookmark without duplicating an existing favorite" do
    favorite = create(:document_bookmark, user:, document:, bookmark_type: :favorite)
    read_later = create(:document_bookmark, user:, document:, bookmark_type: :read_later)
    sign_in_as(user)

    favorite_count = DocumentBookmark.favorite.count
    expect do
      post move_to_favorite_document_bookmark_path(read_later), params: { view: "read_later" }
    end.to change(DocumentBookmark.read_later, :count).by(-1)

    expect(DocumentBookmark.favorite.count).to eq(favorite_count)
    expect(user.document_bookmarks.favorite.where(document:).sole).to eq(favorite)
    expect(user.document_bookmarks.read_later.where(document:)).to be_empty
    expect(response).to redirect_to(document_bookmarks_path(view: "read_later"))
    expect(flash[:notice]).to be_present
  end

  it "does not move another user's read-later bookmark" do
    bookmark = create(:document_bookmark, user: create(:user, :external, company:), document:, bookmark_type: :read_later)
    sign_in_as(user)

    expect do
      post move_to_favorite_document_bookmark_path(bookmark), params: { view: "read_later" }
    end.not_to change(DocumentBookmark, :count)

    expect(response).to have_http_status(:not_found)
    expect(DocumentBookmark.exists?(bookmark.id)).to be(true)
  end

  it "does not duplicate an existing bookmark" do
    create(:document_bookmark, user:, document:, bookmark_type: :favorite)
    sign_in_as(user)

    expect do
      post document_bookmarks_path, params: { document_bookmark: { document_id: document.public_id, bookmark_type: "favorite" } }
    end.not_to change(DocumentBookmark, :count)
  end

  it "does not create bookmarks for unreadable documents" do
    document.update!(visibility_policy: :internal_only)
    sign_in_as(user)

    expect do
      post document_bookmarks_path, params: { document_bookmark: { document_id: document.public_id, bookmark_type: "favorite" } }
    end.not_to change(DocumentBookmark, :count)

    expect(response).to have_http_status(:forbidden)
    expect(user.document_bookmarks.favorite.where(document:).exists?).to be(false)
  end

  it "does not move bookmarks for unreadable documents" do
    bookmark = create(:document_bookmark, user:, document:, bookmark_type: :read_later)
    document.update!(visibility_policy: :internal_only)
    sign_in_as(user)

    expect do
      post move_to_favorite_document_bookmark_path(bookmark), params: { view: "read_later" }
    end.not_to change(DocumentBookmark, :count)

    expect(response).to have_http_status(:forbidden)
    expect(DocumentBookmark.exists?(bookmark.id)).to be(true)
    expect(user.document_bookmarks.favorite.where(document:).exists?).to be(false)
  end

  it "destroys only the current user's bookmark" do
    bookmark = create(:document_bookmark, user:, document:, bookmark_type: :favorite)
    sign_in_as(user)

    expect { delete document_bookmark_path(bookmark), params: { view: "favorite" } }.to change(DocumentBookmark, :count).by(-1)
    expect(DocumentBookmark.exists?(bookmark.id)).to be(false)

    other_bookmark = create(:document_bookmark, user: create(:user, :external, company:), document:, bookmark_type: :favorite)
    expect { delete document_bookmark_path(other_bookmark), params: { view: "favorite" } }.not_to change(DocumentBookmark, :count)
    expect(response).to have_http_status(:not_found)
    expect(DocumentBookmark.exists?(other_bookmark.id)).to be(true)
  end
end
