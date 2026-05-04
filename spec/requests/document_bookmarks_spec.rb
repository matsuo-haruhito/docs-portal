require "rails_helper"

RSpec.describe "Document bookmarks", type: :request do
  let(:company) { create(:company) }
  let(:project) { create(:project) }
  let(:user) { create(:user, :external, company:) }
  let(:document) { create(:document, project:, title: "Manual", slug: "manual", visibility_policy: :restricted_external) }

  before do
    create(:project_membership, project:, user:)
    create(:document_permission, document:, company:, access_level: :view)
  end

  it "shows bookmark lists" do
    create(:document_bookmark, user:, document:, bookmark_type: :favorite)
    sign_in_as(user)

    get document_bookmarks_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("文書ショートカット")
    expect(response.body).to include("Manual")
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
end
