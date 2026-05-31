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

  it "shows bookmark lists with project context and section cues" do
    later_document = create(:document, project:, title: "Checklist", slug: "checklist", visibility_policy: :restricted_external)
    recent_document = create(:document, project:, title: "Guide", slug: "guide", visibility_policy: :restricted_external)
    create(:document_permission, document: later_document, company:, access_level: :view)
    create(:document_permission, document: recent_document, company:, access_level: :view)
    create(:document_bookmark, user:, document:, bookmark_type: :favorite)
    create(:document_bookmark, user:, document: later_document, bookmark_type: :read_later)
    create(:access_log, user:, company:, project:, document: recent_document, action_type: :view, target_type: "document", accessed_at: Time.current)
    sign_in_as(user)

    get document_bookmarks_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("文書ショートカット")
    expect(response.body).to include("Manual")
    expect(response.body).to include("Checklist")
    expect(response.body).to include("Guide")
    expect(response.body).to include("Visible Project")
    expect(response.body).to include("お気に入り")
    expect(response.body).to include("後で読む")
    expect(response.body).to include("最近見た文書")
    expect(response.body.scan("1件").size).to eq(3)
    expect(response.body).to include("よく開く文書をここからすぐ確認できます。")
    expect(response.body).to include("あとで確認したい文書を一時的に集めておけます。")
    expect(response.body).to include("閲覧履歴から自動で表示されます。お気に入りや後で読むとは別の一覧です。")
    expect(response.body).to include("よく開く文書")
    expect(response.body).to include("あとで確認")
    expect(response.body).to include("最近見た文書")
    expect(response.body.scan("解除").size).to eq(2)
    expect(response.body.scan("お気に入りへ移す").size).to eq(1)
  end

  it "shows actionable empty states with zero counts" do
    sign_in_as(user)

    get document_bookmarks_path

    expect(response).to have_http_status(:ok)
    expect(response.body.scan("0件").size).to eq(3)
    expect(response.body).to include("文書画面でお気に入りに追加すると、ここに表示されます。")
    expect(response.body).to include("文書画面で後で読むに追加すると、ここに表示されます。")
    expect(response.body).to include("文書を開くと、最近見た文書としてここに表示されます。")
  end

  it "does not list bookmarks for documents no longer readable by the current user" do
    hidden_document = create(:document, title: "Hidden Manual", slug: "hidden-manual", visibility_policy: :restricted_external)
    create(:document_bookmark, user:, document:, bookmark_type: :favorite)
    create(:document_bookmark, user:, document: hidden_document, bookmark_type: :favorite)
    sign_in_as(user)

    get document_bookmarks_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Manual")
    expect(response.body).not_to include("Hidden Manual")
  end

  it "creates a favorite bookmark" do
    sign_in_as(user)

    expect do
      post document_bookmarks_path, params: {
        document_bookmark: {
          document_id: document.public_id,
          bookmark_type: "favorite"
        }
      }
    end.to change(DocumentBookmark.favorite, :count).by(1)

    expect(response).to redirect_to(root_path)
  end

  it "creates a read-later bookmark" do
    sign_in_as(user)

    expect do
      post document_bookmarks_path, params: {
        document_bookmark: {
          document_id: document.public_id,
          bookmark_type: "read_later"
        }
      }
    end.to change(DocumentBookmark.read_later, :count).by(1)
  end

  it "falls back to favorite when bookmark_type is invalid" do
    sign_in_as(user)

    expect do
      post document_bookmarks_path, params: {
        document_bookmark: {
          document_id: document.public_id,
          bookmark_type: "unexpected"
        }
      }
    end.to change(DocumentBookmark.favorite, :count).by(1)

    expect(user.document_bookmarks.sole).to be_favorite
    expect(response).to redirect_to(root_path)
  end

  it "does not duplicate an existing bookmark" do
    create(:document_bookmark, user:, document:, bookmark_type: :favorite)
    sign_in_as(user)

    expect do
      post document_bookmarks_path, params: {
        document_bookmark: {
          document_id: document.public_id,
          bookmark_type: "favorite"
        }
      }
    end.not_to change(DocumentBookmark, :count)
  end

  it "moves a read-later bookmark to favorites" do
    bookmark = create(:document_bookmark, user:, document:, bookmark_type: :read_later)
    sign_in_as(user)

    expect do
      post move_to_favorite_document_bookmark_path(bookmark)
    end.to change(DocumentBookmark.favorite, :count).by(1)
      .and change(DocumentBookmark.read_later, :count).by(-1)

    expect(response).to redirect_to(root_path)
    expect(flash[:notice]).to eq("お気に入りへ移しました。")
    expect(user.document_bookmarks.find_by(document:, bookmark_type: :favorite)).to be_present
    expect(user.document_bookmarks.find_by(document:, bookmark_type: :read_later)).to be_nil
  end

  it "moves a read-later bookmark without duplicating an existing favorite" do
    bookmark = create(:document_bookmark, user:, document:, bookmark_type: :read_later)
    create(:document_bookmark, user:, document:, bookmark_type: :favorite)
    favorite_count = DocumentBookmark.favorite.count
    sign_in_as(user)

    expect do
      post move_to_favorite_document_bookmark_path(bookmark)
    end.to change(DocumentBookmark.read_later, :count).by(-1)

    expect(DocumentBookmark.favorite.count).to eq(favorite_count)
    expect(user.document_bookmarks.where(document:, bookmark_type: :favorite).count).to eq(1)
    expect(user.document_bookmarks.find_by(document:, bookmark_type: :read_later)).to be_nil
  end

  it "does not move another user's read-later bookmark" do
    other_user = create(:user, :external, company:)
    bookmark = create(:document_bookmark, user: other_user, document:, bookmark_type: :read_later)
    sign_in_as(user)

    expect do
      post move_to_favorite_document_bookmark_path(bookmark)
    end.not_to change(DocumentBookmark, :count)

    expect(response).to have_http_status(:not_found)
    expect(bookmark.reload).to be_present
  end

  it "does not move unreadable documents to favorites" do
    bookmark = create(:document_bookmark, user:, document:, bookmark_type: :read_later)
    document.update!(visibility_policy: :internal_only)
    sign_in_as(user)

    expect do
      post move_to_favorite_document_bookmark_path(bookmark)
    end.not_to change(DocumentBookmark, :count)

    expect(response).to have_http_status(:forbidden)
    expect(bookmark.reload).to be_present
    expect(user.document_bookmarks.find_by(document:, bookmark_type: :favorite)).to be_nil
  end

  it "does not create bookmarks for unreadable documents" do
    document.update!(visibility_policy: :internal_only)
    sign_in_as(user)

    expect do
      post document_bookmarks_path, params: {
        document_bookmark: {
          document_id: document.public_id,
          bookmark_type: "favorite"
        }
      }
    end.not_to change(DocumentBookmark, :count)

    expect(response).to have_http_status(:forbidden)
  end

  it "destroys the user's bookmark" do
    bookmark = create(:document_bookmark, user:, document:, bookmark_type: :favorite)
    sign_in_as(user)

    expect do
      delete document_bookmark_path(bookmark)
    end.to change(DocumentBookmark, :count).by(-1)
  end

  it "does not destroy another user's bookmark" do
    other_user = create(:user, :external, company:)
    bookmark = create(:document_bookmark, user: other_user, document:, bookmark_type: :favorite)
    sign_in_as(user)

    expect do
      delete document_bookmark_path(bookmark)
    end.not_to change(DocumentBookmark, :count)

    expect(response).to have_http_status(:not_found)
    expect(bookmark.reload).to be_present
  end
end
