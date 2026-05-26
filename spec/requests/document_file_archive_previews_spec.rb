require "rails_helper"
require "fileutils"

RSpec.describe "Document file archive previews", type: :request do
  let(:user) { create(:user, :internal) }
  let(:project) { create(:project, code: "ARCHIVEPREV", name: "Archive Preview Project") }
  let(:document) { create(:document, project:, title: "Archive Preview Manual", slug: "archive-preview-manual") }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0") }
  let(:archive_file) do
    DocumentFile.create!(
      document_version: version,
      file_name: "attachments.zip",
      content_type: "application/zip",
      storage_key: "spec/request-archive-preview/attachments.zip",
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

  it "shows Japanese labels for archive preview summary, filters, and actions" do
    write_zip(
      "docs/" => :directory,
      "docs/readme.txt" => "one\ntwo\n",
      "images/" => :directory,
      "images/logo.png" => "png"
    )
    sign_in_as(user)

    get document_file_path(archive_file, embedded: "1", disposition: "inline")

    body = response.body.dup.force_encoding("UTF-8")

    expect(response).to have_http_status(:ok)
    expect(body).to include("ZIP内サマリー")
    expect(body).to include("ファイル数")
    expect(body).to include("フォルダ数")
    expect(body).to include("テキスト確認候補")
    expect(body).to include("ダウンロード候補")
    expect(body).to include("プレビュー候補")
    expect(body).to include("要注意パス")
    expect(body).to include("個別ダウンロード")
    expect(body).not_to include(">files<")
    expect(body).not_to include(">folders<")
    expect(body).not_to include("entry path")
    expect(body).not_to include("download entry")
  end
end
