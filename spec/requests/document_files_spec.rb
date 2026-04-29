require "rails_helper"
require "fileutils"
require "securerandom"

RSpec.describe "Document files", type: :request do
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
  let(:markdown_file) do
    DocumentFile.create!(
      document_version: version,
      file_name: "README.md",
      content_type: "application/octet-stream",
      storage_key: "spec/README.md",
      file_size: 20,
      sort_order: 1
    )
  end

  before do
    FileUtils.mkdir_p(file.absolute_path.dirname)
    File.write(file.absolute_path, "%PDF-1.4")
    File.write(markdown_file.absolute_path, "# hello\n")
  end

  after do
    FileUtils.rm_f(file.absolute_path)
    FileUtils.rm_f(markdown_file.absolute_path)
  end

  it "downloads the file and records an access log" do
    sign_in_as(user)

    expect do
      get document_file_path(file)
    end.to change(AccessLog, :count).by(1)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/pdf")

    log = AccessLog.order(:id).last
    expect(log.user).to eq(user)
    expect(log.project).to eq(project)
    expect(log.document).to eq(document)
    expect(log.document_version).to eq(version)
    expect(log.action_type).to eq("download")
    expect(log.target_name).to eq("manual.pdf")
  end

  it "returns not found when the stored file is missing" do
    sign_in_as(user)
    FileUtils.rm_f(file.absolute_path)

    get document_file_path(file)

    expect(response).to have_http_status(:not_found)
    expect(response.body).to eq("File not found")
  end

  it "serves markdown files inline" do
    sign_in_as(user)

    get document_file_path(markdown_file)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/markdown")
    expect(response.headers["content-disposition"]).to include("inline")
  end
end
