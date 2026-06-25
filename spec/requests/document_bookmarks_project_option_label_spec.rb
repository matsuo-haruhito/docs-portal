require "rails_helper"

RSpec.describe "Document bookmark project option label", type: :request do
  let(:company) { create(:company) }
  let(:project) { create(:project, name: "Visible Project", code: "VIS-001") }
  let(:user) { create(:user, :external, company:) }
  let(:document) { create(:document, project:, title: "Manual", slug: "manual", visibility_policy: :restricted_external) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  before do
    create(:project_membership, project:, user:)
    create(:document_permission, document:, company:, access_level: :view)
    create(:document_bookmark, user:, document:, bookmark_type: :favorite)
  end

  it "shows project code in the saved shortcut project selector without changing the submitted value" do
    sign_in_as(user)

    get document_bookmarks_path

    expect(response).to have_http_status(:ok)

    option = parsed_html.css("select[name='project_code'] option").find { _1["value"] == "VIS-001" }
    expect(option).to be_present
    expect(option.text.squish).to eq("Visible Project（VIS-001）")
  end
end
