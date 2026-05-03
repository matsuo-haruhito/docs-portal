require "rails_helper"

RSpec.describe "Rparam document filters", type: :request do
  let(:user) { create(:user, :internal) }
  let(:project) { create(:project, code: "RPARAM", name: "Rparam Project") }

  it "normalizes invalid page values" do
    document = create(:document, project:, title: "Rparam Document", slug: "rparam-doc")
    create(:document_version, document:)

    sign_in_as(user)

    get project_documents_path(project, page: "-10")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Page 1 / 1")
    expect(response.body).to include("Rparam Document")
  end
end
