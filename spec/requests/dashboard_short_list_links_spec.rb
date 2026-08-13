require "rails_helper"

RSpec.describe "Dashboard short-list links", type: :request do
  let(:company) { create(:company) }
  let(:project) { create(:project, name: "Visible Project") }
  let(:user) { create(:user, :external, company:) }

  before { create(:project_membership, project:, user:) }

  it "links a populated recent list to the recent bookmarks tab" do
    document = create(:document, project:, title: "Recent Manual", slug: "recent-manual", visibility_policy: :restricted_external)
    create(:document_permission, document:, company:, access_level: :view)
    create(:access_log, user:, company:, project:, document:, action_type: :view, target_type: "document", accessed_at: Time.current)
    sign_in_as(user)

    get dashboard_path

    link = Nokogiri::HTML(response.body).css("a").find { _1.text.squish == "すべて見る" }
    expect(response).to have_http_status(:ok)
    expect(link["href"]).to eq(document_bookmarks_path(view: "recent"))
    expect(link["data-turbo-frame"]).to eq("_top")
  end

  it "keeps the empty recent state linked to document discovery" do
    sign_in_as(user)

    get dashboard_path

    link = Nokogiri::HTML(response.body).css("a").find { _1.text.squish == "文書を探す" }
    expect(response).to have_http_status(:ok)
    expect(link["href"]).to eq(documents_path)
  end
end
