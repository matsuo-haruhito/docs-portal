require "rails_helper"
require "securerandom"

RSpec.describe "Document views", type: :request do
  let(:user) { create(:user, :internal) }
  let(:project) { create(:project, code: "PJ#{SecureRandom.hex(4)}", name: "Project #{SecureRandom.hex(2)}") }
  let(:document) { create(:document, project:, title: "運用手順", slug: "operation-manual") }

  it "returns a clearer message when rendered html is unavailable" do
    version = create(
      :document_version,
      document:,
      version_label: "v1.0.0",
      markdown_entry_path: "docs/README.md",
      site_build_path: "docs/v1.0.0"
    )

    sign_in_as(user)
    get view_document_version_path(version)

    expect(response).to have_http_status(:not_found)
    expect(response.body).to include("Rendered HTML is not available")
  end

  it "hides the rendered view link when html does not exist" do
    version = create(
      :document_version,
      document:,
      version_label: "v1.0.0",
      markdown_entry_path: "docs/README.md",
      site_build_path: "docs/v1.0.0"
    )

    sign_in_as(user)
    get project_document_path(project, document)

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include(view_document_version_path(version))
  end
end
