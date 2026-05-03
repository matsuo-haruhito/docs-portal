require "rails_helper"
require "securerandom"

RSpec.describe "Public identifier routes", type: :request do
  let(:user) { create(:user, :internal) }
  let(:project) { create(:project, code: "PJ#{SecureRandom.hex(4)}", name: "Project #{SecureRandom.hex(2)}") }
  let(:document) { create(:document, project:, title: "運用手順", slug: "operation-manual") }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0") }
  let(:file) do
    DocumentFile.create!(
      document_version: version,
      file_name: "manual.pdf",
      content_type: "application/pdf",
      storage_key: "spec/manual.pdf",
      file_size: 12
    )
  end

  it "uses code, slug, and public_id for public-facing route helpers" do
    expect(project_path(project)).to include(project.code)
    expect(project_document_path(project, document.slug)).to include(document.slug)
    expect(view_document_version_path(version)).to include(version.public_id)
    expect(document_file_path(file)).to include(file.public_id)
  end

  it "does not resolve public-facing routes by numeric ids" do
    sign_in_as(user)

    get "/projects/#{project.id}"
    expect(response).to have_http_status(:not_found)

    get "/projects/#{project.code}/documents/#{document.id}"
    expect(response).to have_http_status(:not_found)

    get "/document_versions/#{version.id}/view"
    expect(response).to have_http_status(:not_found)

    get "/document_files/#{file.id}"
    expect(response).to have_http_status(:not_found)
  end
end
