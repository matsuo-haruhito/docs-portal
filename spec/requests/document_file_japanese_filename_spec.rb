require "rails_helper"
require "fileutils"
require "securerandom"

RSpec.describe "Document file Japanese filenames", type: :request do
  let(:user) { create(:user, :internal) }
  let(:project) { create(:project) }
  let(:document) { create(:document, project:, title: "日本語添付", slug: "japanese-attachment") }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0") }
  let(:document_file) do
    DocumentFile.create!(
      document_version: version,
      file_name: "操作説明書.txt",
      content_type: "text/plain",
      storage_key: "spec/document-file-japanese/#{SecureRandom.hex(8)}/manual.txt",
      file_size: 4
    )
  end

  before do
    document.update!(latest_version: version)
    FileUtils.mkdir_p(document_file.absolute_path.dirname)
    File.binwrite(document_file.absolute_path, "body")
  end

  after do
    FileUtils.rm_rf(Rails.root.join("storage", "document_files", "spec", "document-file-japanese"))
  end

  it "sets a UTF-8 filename in Content-Disposition for Japanese attachment downloads" do
    sign_in_as(user)

    get document_file_path(document_file, disposition: "download")

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/plain")
    expect(response.headers["content-disposition"]).to include("attachment")
    expect(response.headers["content-disposition"]).to include("filename*=UTF-8''%E6%93%8D%E4%BD%9C%E8%AA%AC%E6%98%8E%E6%9B%B8.txt")
  end
end
