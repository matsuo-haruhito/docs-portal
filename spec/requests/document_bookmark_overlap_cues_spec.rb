require "rails_helper"

RSpec.describe "Document bookmark overlap cues", type: :request do
  let(:company) { create(:company) }
  let(:project) { create(:project, name: "Shortcut Project") }
  let(:user) { create(:user, :external, company:) }
  let(:document) { create(:document, project:, title: "Shared Manual", slug: "shared-manual", visibility_policy: :restricted_external) }

  before do
    create(:project_membership, project:, user:)
    create(:document_permission, document:, company:, access_level: :view)
  end

  it "shows the overlap cue only on the read-later panel" do
    create(:document_bookmark, user:, document:, bookmark_type: :favorite)
    create(:document_bookmark, user:, document:, bookmark_type: :read_later)
    sign_in_as(user)

    get document_bookmarks_path, params: { view: "read_later" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Shared Manual", "お気に入りにも保存中", "お気に入りへ移す")
    expect(Nokogiri::HTML(response.body).at_css("#favorite-bookmarks")).to be_nil
  end

  it "does not show the overlap cue without a favorite bookmark" do
    create(:document_bookmark, user:, document:, bookmark_type: :read_later)
    sign_in_as(user)

    get document_bookmarks_path, params: { view: "read_later" }

    expect(response.body).to include("Shared Manual")
    expect(response.body).not_to include("お気に入りにも保存中")
  end
end
