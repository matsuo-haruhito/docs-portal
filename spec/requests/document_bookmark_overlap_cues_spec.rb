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

  it "shows a short cue when the same document is both favorite and read-later" do
    create(:document_bookmark, user:, document:, bookmark_type: :favorite)
    create(:document_bookmark, user:, document:, bookmark_type: :read_later)

    sign_in_as(user)
    get document_bookmarks_path

    expect(response).to have_http_status(:ok)
    aggregate_failures do
      expect(response.body).to include("Shared Manual")
      expect(response.body.scan("お気に入りにも保存中").size).to eq(1)
      expect(response.body).to include("継続参照はお気に入りに残し、後で読むだけ整理できます。")
      expect(response.body).to include("移すと後で読むから外れ、お気に入りだけに残ります。")
      expect(response.body.scan("お気に入りへ移す").size).to eq(1)
    end
  end

  it "does not show the overlap cue for a read-later document without a favorite bookmark" do
    create(:document_bookmark, user:, document:, bookmark_type: :read_later)

    sign_in_as(user)
    get document_bookmarks_path

    expect(response).to have_http_status(:ok)
    aggregate_failures do
      expect(response.body).to include("Shared Manual")
      expect(response.body).not_to include("お気に入りにも保存中")
      expect(response.body).not_to include("移すと後で読むから外れ、お気に入りだけに残ります。")
    end
  end
end
