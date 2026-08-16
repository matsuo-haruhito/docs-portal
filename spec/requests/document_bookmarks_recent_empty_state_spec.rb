require "rails_helper"

RSpec.describe "Document bookmark recent empty state", type: :request do
  let(:company) { create(:company) }
  let(:project) { create(:project, name: "Visible Project") }
  let(:user) { create(:user, :external, company:) }

  before { create(:project_membership, project:, user:) }

  it "keeps recent view and saved filters on the filtered empty-state clear link" do
    document = create(:document, project:, title: "Guide", slug: "guide", visibility_policy: :restricted_external)
    create(:document_permission, document:, company:, access_level: :view)
    create(:access_log, user:, company:, project:, document:, action_type: :view, target_type: "document", accessed_at: Time.current)
    sign_in_as(user)

    get document_bookmarks_path, params: {
      view: "recent", project_code: project.code, bookmark_q: "manual", recent_q: "zzz", favorite_page: 2, read_later_page: 3
    }

    recent_section = Nokogiri::HTML(response.body).at_css("#recent-documents")
    clear_link = recent_section.css("a").find { _1.text.squish == "条件をクリア" }

    expect(response).to have_http_status(:ok)
    expect(clear_link).to be_present
    expect(clear_link["href"]).to include("view=recent", "project_code=#{project.code}", "bookmark_q=manual")
    expect(clear_link["href"]).not_to include("recent_q")
  end
end
