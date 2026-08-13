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

  it "lists only the current user's readable bookmarks in the selected tab" do
    favorite = create(:document, project:, title: "Current Favorite", slug: "current-favorite", visibility_policy: :restricted_external)
    later = create(:document, project:, title: "Current Read Later", slug: "current-read-later", visibility_policy: :restricted_external)
    other = create(:document, project:, title: "Other User Favorite", slug: "other-user-favorite", visibility_policy: :restricted_external)
    [favorite, later, other].each { |document| create(:document_permission, document:, company:, access_level: :view) }
    create(:document_bookmark, user:, document: favorite, bookmark_type: :favorite)
    create(:document_bookmark, user:, document: later, bookmark_type: :read_later)
    create(:document_bookmark, user: other_user, document: other, bookmark_type: :favorite)
    sign_in_as(user)

    get document_bookmarks_path, params: { view: "favorite" }
    expect(response.body).to include("Current Favorite")
    expect(response.body).not_to include("Current Read Later", "Other User Favorite")

    get document_bookmarks_path, params: { view: "read_later" }
    expect(response.body).to include("Current Read Later")
    expect(response.body).not_to include("Current Favorite", "Other User Favorite")
  end
end
