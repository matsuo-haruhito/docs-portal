require "rails_helper"
require "fileutils"

RSpec.describe "Document file preview header actions", type: :request do
  let(:user) { create(:user, :internal) }
  let(:project) { create(:project, code: "PREV", name: "Preview Project") }
  let(:document) { create(:document, project:, title: "Preview Manual", slug: "preview-manual") }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0") }
  let(:file) do
    DocumentFile.create!(
      document_version: version,
      file_name: "long-preview-manual-for-action-copy.pdf",
      content_type: "application/pdf",
      storage_key: "spec/long-preview-manual-for-action-copy.pdf",
      file_size: 8,
      scan_status: :scan_clean
    )
  end

  before do
    FileUtils.mkdir_p(file.absolute_path.dirname)
    File.binwrite(file.absolute_path, "%PDF-1.4")
  end

  after do
    FileUtils.rm_f(file.absolute_path)
  end

  it "separates the open-in-new-tab action from the save-file action without changing routes" do
    sign_in_as(user)

    get document_file_path(file, disposition: "inline")

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/html")
    expect(response.body).to include("PDFを別タブで開く")
    expect(response.body).to include("target=\"_blank\"")
    expect(response.body).to include("rel=\"noopener\"")
    expect(response.body).to include("別タブで表示するリンクと、手元へ保存するリンクです。")
    expect(response.body).to include("ファイルを保存")
    expect(response.body).to include(document_file_path(file, disposition: "download"))
  end
end
