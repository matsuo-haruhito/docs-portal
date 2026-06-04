require "rails_helper"
require "fileutils"
require "securerandom"
require "zip"

RSpec.describe "Document file archive preview path search", type: :request do
  let(:user) { create(:user, :internal) }
  let(:project) { create(:project, code: "PJ#{SecureRandom.hex(4)}", name: "Project #{SecureRandom.hex(2)}") }
  let(:document) { create(:document, project:, title: "運用手順", slug: "operation-manual") }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0") }

  def create_zip_preview_file(entries)
    zip_file = DocumentFile.create!(
      document_version: version,
      file_name: "bundle.zip",
      content_type: "application/zip",
      storage_key: "spec/archive-preview-path-search-#{SecureRandom.hex(4)}.zip",
      file_size: 0,
      scan_status: :scan_clean
    )

    @preview_files ||= []
    @preview_files << zip_file

    FileUtils.mkdir_p(zip_file.absolute_path.dirname)
    Zip::OutputStream.open(zip_file.absolute_path.to_s) do |zip|
      entries.each do |entry_name, content|
        zip.put_next_entry(entry_name)
        zip.write(content) unless content == :directory
      end
    end
    zip_file.update!(file_size: File.size(zip_file.absolute_path))

    zip_file
  end

  after do
    Array(@preview_files).each { |preview_file| FileUtils.rm_f(preview_file.absolute_path) }
  end

  it "finds a ZIP entry outside the default visible limit by path query" do
    entries = (1..DocumentFileArchivePreview::DEFAULT_LIMIT).to_h do |entry_number|
      [format("docs/file-%03d.txt", entry_number), "file #{entry_number}\n"]
    end
    entries["deep/target.txt"] = "target\n"
    zip_file = create_zip_preview_file(entries)
    sign_in_as(user)

    get document_file_path(zip_file, disposition: "inline")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("先頭 #{DocumentFileArchivePreview::DEFAULT_LIMIT} 件を表示しています")
    expect(response.body).to include("docs/file-300.txt")
    expect(response.body).not_to include("deep/target.txt")

    get document_file_path(zip_file, disposition: "inline", q: "target")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("ZIP全体path検索")
    expect(response.body).to include("ZIP全体のpathから検索しています")
    expect(response.body).to include("deep/target.txt")
    expect(response.body).not_to include("docs/file-300.txt")
  end

  it "keeps unsafe and nested archive action boundaries in path search results" do
    zip_file = create_zip_preview_file({
      "docs/readme.txt" => "hello\n",
      "deep/target.txt" => "target\n",
      "deep/target.zip" => "zip bytes",
      "../target-secret.txt" => "unsafe\n"
    })
    sign_in_as(user)

    get document_file_path(zip_file, disposition: "inline", q: "target")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("deep/target.txt")
    expect(response.body).to include("deep/target.zip")
    expect(response.body).to include("../target-secret.txt")
    expect(response.body).to include("nested archive entry はdownload対象外です")
    expect(response.body).to include("unsafe path のため操作できません")
    expect(response.body).to include("確認可能")
    expect(response.body).to include("取得可能")
  end

  it "shows a path-search empty state instead of the empty ZIP message" do
    zip_file = create_zip_preview_file({ "docs/readme.txt" => "hello\n" })
    sign_in_as(user)

    get document_file_path(zip_file, disposition: "inline", q: "missing")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("一致するZIP項目がありません")
    expect(response.body).to include("ZIP全体path検索に一致する項目がありません")
    expect(response.body).not_to include("空のZIPファイルです")
  end
end
