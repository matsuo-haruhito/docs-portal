require "rails_helper"
require "fileutils"
require "securerandom"

RSpec.describe "Document file Office previews", type: :request do
  let(:user) { create(:user, :internal) }
  let(:project) { create(:project, code: "PJ#{SecureRandom.hex(4)}", name: "Project #{SecureRandom.hex(2)}") }
  let(:document) { create(:document, project:, title: "提案書", slug: "proposal") }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0") }
  let(:office_file) do
    DocumentFile.create!(
      document_version: version,
      file_name: "proposal.docx",
      content_type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
      storage_key: "spec/proposal.docx",
      file_size: 12,
      scan_status: :scan_clean
    )
  end

  before do
    FileUtils.mkdir_p(office_file.absolute_path.dirname)
    File.binwrite(office_file.absolute_path, "docx")
  end

  after do
    FileUtils.rm_f(office_file.absolute_path)
  end

  it "redirects embedded Office file requests to a Microsoft Graph preview URL" do
    create(:microsoft_graph_connection, project:)
    sign_in_as(user)
    allow_any_instance_of(MicrosoftGraphClient).to receive(:preview_url_for_upload).and_return("https://example.sharepoint.com/preview")

    get document_file_path(office_file, disposition: "inline", embedded: "1")

    expect(response).to redirect_to("https://example.sharepoint.com/preview")
  end

  it "treats Office files as embedded viewer candidates" do
    expect(office_file).to be_office_previewable
    expect(office_file).to be_embeddable_viewer_file
    expect(version.embedded_view_file).to eq(office_file)
  end

  it "shows a download-only notice for Office files over 250MB" do
    create(:microsoft_graph_connection, project:)
    office_file.update!(file_size: 251.megabytes)
    sign_in_as(user)

    expect_any_instance_of(MicrosoftGraphClient).not_to receive(:preview_url_for_upload)

    get document_file_path(office_file, disposition: "inline", embedded: "1")

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/html")
    expect(response.body).to include("プレビュー不可")
    expect(response.body).to include("250MBを超えているため")
    expect(response.body).to include(document_file_path(office_file, disposition: "download"))
  end

  it "returns bad gateway when Microsoft Graph preview cannot be created" do
    create(:microsoft_graph_connection, project:)
    sign_in_as(user)
    allow_any_instance_of(MicrosoftGraphClient).to receive(:preview_url_for_upload).and_raise(MicrosoftGraphClient::Error, "preview failed")

    get document_file_path(office_file, disposition: "inline", embedded: "1")

    expect(response).to have_http_status(:bad_gateway)
    expect(response.body).to include("Office preview is not available")
  end
end
