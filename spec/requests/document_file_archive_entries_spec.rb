require "rails_helper"
require "fileutils"

RSpec.describe "Document file archive entries", type: :request do
  let(:user) { create(:user, :internal) }
  let(:project) { create(:project, code: "ARCHIVE", name: "Archive Project") }
  let(:document) { create(:document, project:, title: "Archive Manual", slug: "archive-manual") }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0") }
  let(:archive_file) do
    DocumentFile.create!(
      document_version: version,
      file_name: "attachments.zip",
      content_type: "application/zip",
      storage_key: "spec/request-archive-entry/attachments.zip",
      file_size: 1,
      scan_status: :scan_clean
    )
  end

  def write_zip(entries)
    FileUtils.mkdir_p(archive_file.absolute_path.dirname)
    Zip::File.open(archive_file.absolute_path, create: true) do |zip_file|
      entries.each do |name, content|
        if content == :directory
          zip_file.mkdir(name)
        else
          zip_file.get_output_stream(name) { |io| io.write(content) }
        end
      end
    end
    archive_file.update!(file_size: File.size(archive_file.absolute_path))
  end

  def grant_external_access(external_user, access_level: :view)
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document:, company: external_user.company, access_level:)
  end

  def preview_entry_path(entry_path = "docs/readme.txt")
    archive_entry_preview_document_file_path(archive_file, entry_path:)
  end

  def download_entry_path(entry_path = "docs/readme.txt")
    archive_entry_download_document_file_path(archive_file, entry_path:)
  end

  after do
    FileUtils.rm_f(archive_file.absolute_path)
  end

  it "previews a text archive entry and records only a view access log" do
    write_zip("docs/readme.txt" => "one\ntwo\n")
    sign_in_as(user)

    expect do
      get preview_entry_path
    end.to change(AccessLog.where(action_type: :view), :count).by(1)
      .and change(AccessLog.where(action_type: :download), :count).by(0)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("ZIP項目プレビュー")
    expect(response.body).to include("ZIP内ファイル一覧へ戻る")
    expect(response.body).to include("個別ダウンロード")
    expect(response.body).to include("archive_entries/download")
    expect(response.body).to include("項目パス")
    expect(response.body).to include("ファイル名")
    expect(response.body).to include("コンテンツタイプ")
    expect(response.body).to include("docs/readme.txt")
    expect(response.body).to include("one")
    expect(response.body).to include("two")
    expect(response.body).not_to include("ZIP entry preview")
    expect(response.body).not_to include("entry path")
  end

  it "adds archive row anchors to entry preview links" do
    write_zip("docs/readme.txt" => "one\ntwo\n")
    sign_in_as(user)

    get document_file_path(archive_file, disposition: "inline")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('id="archive-entry-1"')
    expect(response.body).to include("return_anchor=archive-entry-1")
    expect(response.body).to include("docs%2Freadme.txt")
  end

  it "links back to the archive preview row for valid return anchors" do
    write_zip("docs/readme.txt" => "one\ntwo\n")
    sign_in_as(user)

    get archive_entry_preview_document_file_path(archive_file, entry_path: "docs/readme.txt", return_anchor: "archive-entry-1")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("ZIP内ファイル一覧へ戻る")
    expect(response.body).to include(document_file_path(archive_file, disposition: "inline", anchor: "archive-entry-1"))
  end

  it "does not use unsafe return anchors for archive preview links" do
    write_zip("docs/readme.txt" => "one\ntwo\n")
    sign_in_as(user)

    get archive_entry_preview_document_file_path(archive_file, entry_path: "docs/readme.txt", return_anchor: "https://example.com/archive-entry-1")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("ZIP内ファイル一覧へ戻る")
    expect(response.body).to include(document_file_path(archive_file, disposition: "inline"))
    expect(response.body).not_to include(document_file_path(archive_file, disposition: "inline", anchor: "https://example.com/archive-entry-1"))
    expect(response.body).not_to include('href="https://example.com')
  end

  it "keeps unsafe and nested archive entries out of preview and download candidates" do
    write_zip(
      "docs/readme.txt" => "hello",
      "downloads/report.csv" => "id,name\n1,Archive\n",
      "../evil.txt" => "secret",
      "nested/archive.zip" => "zip"
    )
    sign_in_as(user)

    archive_preview = DocumentFileArchivePreview.new(file: archive_file).call
    safe_text_entry = archive_preview.entries.find { _1.name == "docs/readme.txt" }
    safe_download_entry = archive_preview.entries.find { _1.name == "downloads/report.csv" }
    unsafe_entry = archive_preview.entries.find { _1.name == "../evil.txt" }
    nested_archive_entry = archive_preview.entries.find { _1.name == "nested/archive.zip" }

    expect(safe_text_entry).to be_text_preview_candidate
    expect(safe_download_entry).to be_download_candidate
    expect(unsafe_entry).not_to be_actionable
    expect(unsafe_entry.action_unavailable_reason).to include("unsafe path")
    expect(nested_archive_entry).not_to be_actionable
    expect(nested_archive_entry.action_unavailable_reason).to include("nested archive")

    get preview_entry_path("docs/readme.txt")
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("hello")

    get download_entry_path("downloads/report.csv")
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Archive")

    expect do
      get preview_entry_path("../evil.txt")
    end.to change(AccessLog.where(action_type: :view), :count).by(1)
      .and change(AccessLog.where(action_type: :download), :count).by(0)
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("unsafe path")
    expect(response.body).not_to include("archive_entries/download")

    expect do
      get download_entry_path("../evil.txt")
    end.not_to change(AccessLog.where(action_type: :download), :count)
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("unsafe path")

    expect do
      get download_entry_path("nested/archive.zip")
    end.not_to change(AccessLog.where(action_type: :download), :count)
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("nested archive")
  end

  it "rejects unsafe archive entry paths" do
    write_zip("docs/readme.txt" => "hello")
    sign_in_as(user)

    get preview_entry_path("../secret.txt")

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("ZIP内ファイル一覧へ戻る")
    expect(response.body).not_to include("archive_entries/download")
    expect(response.body).to include("プレビューできません")
    expect(response.body).to include("unsafe path")
  end

  it "does not preview binary archive entries" do
    write_zip("images/logo.png" => "png")
    sign_in_as(user)

    get preview_entry_path("images/logo.png")

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("プレビューできません")
    expect(response.body).to include("text preview")
  end

  it "downloads an archive entry and records only a download access log" do
    write_zip("docs/readme.txt" => "hello")
    sign_in_as(user)

    expect do
      get download_entry_path
    end.to change(AccessLog.where(action_type: :download), :count).by(1)
      .and change(AccessLog.where(action_type: :view), :count).by(0)

    expect(response).to have_http_status(:ok)
    expect(response.body).to eq("hello")
    expect(response.headers["Content-Type"]).to include("text/plain")
    expect(response.headers["Content-Disposition"]).to include("attachment")
    expect(response.headers["Content-Disposition"]).to include("readme.txt")
  end

  it "does not record a download log when entry download is rejected" do
    write_zip("docs/readme.txt" => "hello")
    sign_in_as(user)

    expect do
      get download_entry_path("../secret.txt")
    end.not_to change(AccessLog.where(action_type: :download), :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("unsafe path")
  end

  it "does not download nested archive entries" do
    write_zip("nested/archive.zip" => "zip")
    sign_in_as(user)

    expect do
      get download_entry_path("nested/archive.zip")
    end.not_to change(AccessLog.where(action_type: :download), :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("nested archive")
  end

  it "does not download directory archive entries" do
    write_zip("docs/" => :directory)
    sign_in_as(user)

    expect do
      get download_entry_path("docs/")
    end.not_to change(AccessLog.where(action_type: :download), :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("directory entry")
  end

  it "forbids archive entry downloads for external users who only have view permission" do
    external_user = create(:user, :external)
    grant_external_access(external_user, access_level: :view)
    write_zip("docs/readme.txt" => "hello")
    sign_in_as(external_user)

    expect do
      get download_entry_path
    end.not_to change(AccessLog.where(action_type: :download), :count)

    expect(response).to have_http_status(:forbidden)
  end

  it "forbids external archive entry preview and download while scan is not clean" do
    external_user = create(:user, :external)
    grant_external_access(external_user, access_level: :download)
    write_zip("docs/readme.txt" => "hello")
    sign_in_as(external_user)

    %i[scan_pending scan_failed].each do |scan_status|
      archive_file.update!(scan_status:)

      expect do
        get preview_entry_path
      end.not_to change(AccessLog.where(action_type: :view), :count)
      expect(response).to have_http_status(:forbidden)

      expect do
        get download_entry_path
      end.not_to change(AccessLog.where(action_type: :download), :count)
      expect(response).to have_http_status(:forbidden)
    end
  end

  it "redirects archive entry preview to first-view consent and does not log before consent" do
    external_user = create(:user, :external)
    grant_external_access(external_user, access_level: :view)
    term = create(:consent_term, title: "Preview Terms", consent_scope: :project, version_label: "v1")
    create(:project_consent_setting, project:, consent_term: term, required_on: :first_access)
    write_zip("docs/readme.txt" => "hello")
    sign_in_as(external_user)

    expect do
      get preview_entry_path
    end.not_to change(AccessLog.where(action_type: :view), :count)

    expect(response).to redirect_to(
      new_consent_path(
        target_type: "Project",
        target_public_id: project.public_id,
        timing: :first_view,
        return_to: preview_entry_path
      )
    )
  end

  it "redirects archive entry download to download consent and does not log before consent" do
    external_user = create(:user, :external)
    grant_external_access(external_user, access_level: :download)
    term = create(:consent_term, title: "Download Terms", consent_scope: :download, version_label: "v1")
    create(:project_consent_setting, project:, consent_term: term, required_on: :download)
    write_zip("docs/readme.txt" => "hello")
    sign_in_as(external_user)

    expect do
      get download_entry_path
    end.not_to change(AccessLog.where(action_type: :download), :count)

    expect(response).to redirect_to(
      new_consent_path(
        target_type: "Project",
        target_public_id: project.public_id,
        timing: :download,
        return_to: download_entry_path
      )
    )
  end
end
