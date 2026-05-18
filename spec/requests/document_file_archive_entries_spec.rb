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

  after do
    FileUtils.rm_f(archive_file.absolute_path)
  end

  it "previews a text archive entry and records a view access log" do
    write_zip("docs/readme.txt" => "one\ntwo\n")
    sign_in_as(user)

    expect do
      get archive_entry_preview_document_file_path(archive_file, entry_path: "docs/readme.txt")
    end.to change(AccessLog.where(action_type: :view), :count).by(1)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("ZIP entry preview")
    expect(response.body).to include("docs/readme.txt")
    expect(response.body).to include("one")
    expect(response.body).to include("two")
  end

  it "rejects unsafe archive entry paths" do
    write_zip("docs/readme.txt" => "hello")
    sign_in_as(user)

    get archive_entry_preview_document_file_path(archive_file, entry_path: "../secret.txt")

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("previewできません")
    expect(response.body).to include("unsafe path")
  end

  it "does not preview binary archive entries" do
    write_zip("images/logo.png" => "png")
    sign_in_as(user)

    get archive_entry_preview_document_file_path(archive_file, entry_path: "images/logo.png")

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("previewできません")
    expect(response.body).to include("text preview")
  end
end
