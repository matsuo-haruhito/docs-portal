require "rails_helper"

RSpec.describe "Document bookmark visibility boundaries", type: :request do
  let(:company) { create(:company) }
  let(:project) { create(:project, name: "Readable Project") }
  let(:user) { create(:user, :external, company:) }
  let(:other_user) { create(:user, :external, company:) }

  before do
    create(:project_membership, project:, user:)
    create(:project_membership, project:, user: other_user)
  end

  it "lists only the current user's readable favorite and read-later bookmarks" do
    favorite_document = create(:document, project:, title: "Current Favorite", slug: "current-favorite", visibility_policy: :restricted_external)
    read_later_document = create(:document, project:, title: "Current Read Later", slug: "current-read-later", visibility_policy: :restricted_external)
    other_user_document = create(:document, project:, title: "Other User Favorite", slug: "other-user-favorite", visibility_policy: :restricted_external)
    unreadable_document = create(:document, project:, title: "Unreadable Favorite", slug: "unreadable-favorite", visibility_policy: :restricted_external)

    create(:document_permission, document: favorite_document, company:, access_level: :view)
    create(:document_permission, document: read_later_document, company:, access_level: :view)
    create(:document_permission, document: other_user_document, company:, access_level: :view)

    create(:document_bookmark, user:, document: favorite_document, bookmark_type: :favorite)
    create(:document_bookmark, user:, document: read_later_document, bookmark_type: :read_later)
    create(:document_bookmark, user:, document: unreadable_document, bookmark_type: :favorite)
    create(:document_bookmark, user: other_user, document: other_user_document, bookmark_type: :favorite)
    sign_in_as(user)

    get document_bookmarks_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Current Favorite")
    expect(response.body).to include("Current Read Later")
    expect(response.body).not_to include("Other User Favorite")
    expect(response.body).not_to include("Unreadable Favorite")
    expect(response.body.scan("解除").size).to eq(2)
    expect(response.body.scan("お気に入りへ移す").size).to eq(1)
  end
end
