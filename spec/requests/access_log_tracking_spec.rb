require "rails_helper"
require "fileutils"
require "securerandom"

RSpec.describe "Access log tracking", type: :request do
  let(:internal_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "ACCESS", name: "Access Log Project") }
  let(:document) { create(:document, project:, title: "Access Log Manual", slug: "access-log-manual") }
  let(:site_build_path) { "docs/access-log-manual" }
  let(:version) do
    create(
      :document_version,
      document:,
      version_label: "v1.0.0",
      status: :published,
      site_build_path:
    )
  end
  let(:created_site_roots) { [] }

  def create_stored_document_file(version, file_name:, content:, content_type:, sort_order: 0)
    storage_key = "spec/access-log/#{SecureRandom.hex(8)}/#{file_name}"
    absolute_path = Rails.root.join("storage", "document_files", storage_key)
    FileUtils.mkdir_p(absolute_path.dirname)
    File.binwrite(absolute_path, content)

    DocumentFile.create!(
      document_version: version,
      file_name:,
      content_type:,
      storage_key:,
      file_size: content.bytesize,
      sort_order:,
      scan_status: :scan_clean
    )
  end

  def write_site_file(version, relative_path, content)
    path = version.site_root_absolute_path.join(relative_path)
    FileUtils.mkdir_p(path.dirname)
    File.write(path, content)
    created_site_roots << version.site_root_absolute_path unless created_site_roots.include?(version.site_root_absolute_path)
  end

  def last_access_log
    AccessLog.order(:created_at).last
  end

  before do
    document.update!(latest_version: version)
  end

  after do
    created_site_roots.each { |path| FileUtils.rm_rf(path) }
    FileUtils.rm_rf(Rails.root.join("storage", "document_files", "spec", "access-log"))
  end

  it "records a page view for embedded html document sites" do
    write_site_file(version, "#{site_build_path}/index.html", "<html><body><h1>Access Log Spec</h1></body></html>")
    sign_in_as(internal_user)

    expect do
      get site_document_version_path(version, embedded: "1")
    end.to change(AccessLog.where(action_type: :view, target_type: "page"), :count).by(1)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Access Log Spec")
    expect(last_access_log.action_type).to eq("view")
    expect(last_access_log.target_type).to eq("page")
    expect(last_access_log.target_name).to eq(site_build_path)
  end

  it "records a file view for embedded previews" do
    file = create_stored_document_file(
      version,
      file_name: "attachments/access-log-manual.pdf",
      content: "%PDF-1.4",
      content_type: "application/pdf"
    )
    sign_in_as(internal_user)

    expect do
      get document_file_path(file, embedded: "1")
    end.to change(AccessLog.where(action_type: :view, target_type: "file"), :count).by(1)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/pdf")
    expect(last_access_log.action_type).to eq("view")
    expect(last_access_log.target_type).to eq("file")
    expect(last_access_log.target_name).to eq(file.file_name)
  end

  it "records a file download for non-embedded file requests" do
    file = create_stored_document_file(
      version,
      file_name: "attachments/access-log-manual.pdf",
      content: "%PDF-1.4",
      content_type: "application/pdf"
    )
    sign_in_as(internal_user)

    expect do
      get document_file_path(file)
    end.to change(AccessLog.where(action_type: :download, target_type: "file"), :count).by(1)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/pdf")
    expect(last_access_log.action_type).to eq("download")
    expect(last_access_log.target_type).to eq("file")
    expect(last_access_log.target_name).to eq(file.file_name)
  end

  it "records a zip download for version archives" do
    create_stored_document_file(
      version,
      file_name: "README.md",
      content: "# Access log manual",
      content_type: "text/markdown"
    )
    expected_filename = DocumentVersionZipBuilder.new(
      version:,
      user: internal_user,
      zip_path_mode: "document_title",
      include_markdown_sources: true,
      include_attachments: true,
      pdf_only: false
    ).filename
    sign_in_as(internal_user)

    expect do
      get document_version_archive_path(version)
    end.to change(AccessLog.where(action_type: :download, target_type: "zip"), :count).by(1)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/zip")
    expect(last_access_log.action_type).to eq("download")
    expect(last_access_log.target_type).to eq("zip")
    expect(last_access_log.target_name).to eq(expected_filename)
  end

  it "does not record access logs for static site assets" do
    write_site_file(version, "#{site_build_path}/index.html", "<html><body><h1>Access Log Spec</h1></body></html>")
    write_site_file(version, "assets/css/app.css", "body { color: #333; }")
    sign_in_as(internal_user)

    expect do
      get site_document_version_path(version, site_path: "assets/css/app.css")
    end.not_to change(AccessLog, :count)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/css")
  end
end
