require "rails_helper"
require "fileutils"
require "securerandom"

RSpec.describe "Project document zips", type: :request do
  let(:user) { create(:user, :internal) }
  let(:project) { create(:project, code: "ZIP#{SecureRandom.hex(3)}", name: "Zip Project") }

  def create_document_with_file(title:, slug:, file_name:, content:)
    document = create(:document, project:, title:, slug:)
    version = create(:document_version, document:, version_label: "v1.0.0")
    document.update!(latest_version: version)

    storage_key = "spec/project-document-zips/#{SecureRandom.hex(8)}/#{file_name}"
    absolute_path = Rails.root.join("storage", "document_files", storage_key)
    FileUtils.mkdir_p(absolute_path.dirname)
    File.binwrite(absolute_path, content)

    DocumentFile.create!(
      document_version: version,
      file_name:,
      content_type: "text/plain",
      storage_key:,
      file_size: content.bytesize
    )

    document
  end

  def binary_string(value)
    value.b
  end

  after do
    FileUtils.rm_rf(Rails.root.join("storage", "document_files", "spec", "project-document-zips"))
  end

  it "downloads selected latest document versions as a zip archive and records logs" do
    first = create_document_with_file(title: "First", slug: "first", file_name: "README.md", content: "first")
    second = create_document_with_file(title: "Second", slug: "second", file_name: "guide.txt", content: "second")

    sign_in_as(user)

    expect do
      post project_document_zip_path(project), params: { document_ids: [first.id, second.id] }
    end.to change(AccessLog.where(action_type: :download, target_type: "zip"), :count).by(2)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/zip")
    expect(response.headers["Content-Disposition"]).to include("attachment")
    expect(response.body).to start_with("PK")
    expect(response.body).to include("first/v1.0.0/README.md")
    expect(response.body).to include("second/v1.0.0/guide.txt")
  end

  it "keeps Japanese document and file names in the zip archive" do
    document = create_document_with_file(title: "日本語資料", slug: "nihongo-doc", file_name: "操作説明書.txt", content: "日本語本文")

    sign_in_as(user)

    post project_document_zip_path(project), params: { document_ids: [document.id] }

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/zip")
    expect(response.body).to include(binary_string("nihongo-doc/v1.0.0/操作説明書.txt"))
  end

  it "ignores selected documents outside the current user access scope" do
    external_user = create(:user, :external)
    visible = create_document_with_file(title: "Visible", slug: "visible", file_name: "visible.txt", content: "visible")
    hidden = create_document_with_file(title: "Hidden", slug: "hidden", file_name: "hidden.txt", content: "hidden")
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document: visible, company: external_user.company, access_level: :download)

    sign_in_as(external_user)

    post project_document_zip_path(project), params: { document_ids: [visible.id, hidden.id] }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("visible/v1.0.0/visible.txt")
    expect(response.body).not_to include("hidden/v1.0.0/hidden.txt")
  end

  it "ignores selected documents when the external user only has view permission" do
    external_user = create(:user, :external)
    downloadable = create_document_with_file(title: "Downloadable", slug: "downloadable", file_name: "downloadable.txt", content: "downloadable")
    view_only = create_document_with_file(title: "View Only", slug: "view-only", file_name: "view-only.txt", content: "view-only")
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document: downloadable, company: external_user.company, access_level: :download)
    create(:document_permission, document: view_only, company: external_user.company, access_level: :view)

    sign_in_as(external_user)

    expect do
      post project_document_zip_path(project), params: { document_ids: [downloadable.id, view_only.id] }
    end.to change(AccessLog.where(action_type: :download, target_type: "zip"), :count).by(1)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("downloadable/v1.0.0/downloadable.txt")
    expect(response.body).not_to include("view-only/v1.0.0/view-only.txt")
  end

  it "shows checkbox bulk zip form on the document index" do
    document = create_document_with_file(title: "First", slug: "first", file_name: "README.md", content: "first")

    sign_in_as(user)

    get project_documents_path(project)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(project_document_zip_path(project))
    expect(response.body).to include("document_ids_#{document.id}")
    expect(response.body).to include("選択した文書の最新版をZIPでダウンロード")
  end
end
