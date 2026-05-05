require "rails_helper"
require "fileutils"
require "securerandom"

RSpec.describe "Document version archive Japanese filenames", type: :request do
  let(:user) { create(:user, :internal) }
  let(:project) { create(:project) }
  let(:document) { create(:document, project:, title: "日本語資料", slug: "japanese-doc") }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0", status: :published) }

  before do
    document.update!(latest_version: version)
    storage_key = "spec/versioned-document-japanese/#{SecureRandom.hex(8)}/manual.txt"
    absolute_path = Rails.root.join("storage", "document_files", storage_key)
    FileUtils.mkdir_p(absolute_path.dirname)
    File.binwrite(absolute_path, "body")

    DocumentFile.create!(
      document_version: version,
      file_name: "操作説明書.txt",
      content_type: "text/plain",
      storage_key:,
      file_size: 4
    )
  end

  after do
    FileUtils.rm_rf(Rails.root.join("storage", "document_files", "spec", "versioned-document-japanese"))
  end

  it "keeps Japanese file names in the version zip archive" do
    sign_in_as(user)

    get document_version_archive_path(version)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/zip")
    expect(response.headers["content-disposition"]).to include("attachment")
    expect(response.headers["content-disposition"]).to include("filename*=UTF-8''japanese-doc-v1.0.0.zip")
    expect(response.body).to include("操作説明書.txt".b)
  end
end
