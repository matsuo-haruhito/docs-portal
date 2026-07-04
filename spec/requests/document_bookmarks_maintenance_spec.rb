require "rails_helper"

RSpec.describe "Document bookmarks maintenance mode", type: :request do
  let(:company) { create(:company) }
  let(:project) { create(:project, name: "Visible Project") }
  let(:user) { create(:user, :external, company:) }
  let(:document) { create(:document, project:, title: "Manual", slug: "manual", visibility_policy: :restricted_external) }

  before do
    create(:project_membership, project:, user:)
    create(:document_permission, document:, company:, access_level: :view)
  end

  around do |example|
    original_value = ENV[DocumentBookmarksController::READ_ONLY_MAINTENANCE_ENV]
    ENV[DocumentBookmarksController::READ_ONLY_MAINTENANCE_ENV] = maintenance_env_value
    example.run
  ensure
    if original_value.nil?
      ENV.delete(DocumentBookmarksController::READ_ONLY_MAINTENANCE_ENV)
    else
      ENV[DocumentBookmarksController::READ_ONLY_MAINTENANCE_ENV] = original_value
    end
  end

  describe "when read-only maintenance is enabled" do
    let(:maintenance_env_value) { "1" }

    it "keeps the document bookmark list readable" do
      create(:document_bookmark, user:, document:, bookmark_type: :favorite)
      create(:access_log, user:, company:, project:, document:, action_type: :view, target_type: "document", accessed_at: Time.current)
      sign_in_as(user)

      get document_bookmarks_path, params: { bookmark_q: "manual", recent_q: "manual" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("文書ショートカット")
      expect(response.body).to include("Manual")
      expect(response.body).to include("最近見た文書")
    end

    it "blocks favorite and read-later creation" do
      sign_in_as(user)

      expect do
        post document_bookmarks_path, params: {
          document_bookmark: {
            document_id: document.public_id,
            bookmark_type: "favorite"
          }
        }
      end.not_to change(DocumentBookmark.favorite, :count)

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to include("文書ショートカットの追加・移動・解除は停止しています")

      expect do
        post document_bookmarks_path, params: {
          document_bookmark: {
            document_id: document.public_id,
            bookmark_type: "read_later"
          }
        }
      end.not_to change(DocumentBookmark.read_later, :count)
    end

    it "blocks moving a read-later bookmark to favorite" do
      bookmark = create(:document_bookmark, user:, document:, bookmark_type: :read_later)
      sign_in_as(user)

      expect do
        post move_to_favorite_document_bookmark_path(bookmark)
      end.not_to change(DocumentBookmark, :count)

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to include("文書ショートカットの追加・移動・解除は停止しています")
      expect(bookmark.reload).to be_read_later
      expect(user.document_bookmarks.find_by(document:, bookmark_type: :favorite)).to be_nil
    end

    it "blocks destroying a bookmark while preserving list navigation fallback" do
      bookmark = create(:document_bookmark, user:, document:, bookmark_type: :favorite)
      navigation_params = {
        project_code: project.code,
        bookmark_q: "manual",
        recent_q: "manual",
        favorite_page: 2,
        read_later_page: 3
      }
      sign_in_as(user)

      expect do
        delete document_bookmark_path(bookmark, navigation_params)
      end.not_to change(DocumentBookmark, :count)

      expect(response).to redirect_to(document_bookmarks_path(navigation_params))
      expect(flash[:alert]).to include("文書ショートカットの追加・移動・解除は停止しています")
      expect(bookmark.reload).to be_present
    end
  end

  describe "when read-only maintenance is disabled" do
    let(:maintenance_env_value) { nil }

    it "keeps the existing bookmark creation behavior" do
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
      expect(flash[:notice]).to eq("お気に入りに追加しました。")
    end
  end
end
