require "rails_helper"

RSpec.describe "Admin document file storage usage detail", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "STOR4418", name: "Storage Project") }
  let(:document) { create(:document, project:, title: "Storage Manual", slug: "storage-manual") }
  let(:version) { create(:document_version, document:) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def write_document_file(storage_key, content)
    path = DocumentFile.storage_root.join(storage_key)
    FileUtils.mkdir_p(path.dirname)
    File.binwrite(path, content)
  end

  after do
    FileUtils.rm_rf(DocumentFile.storage_root.join("spec/storage-usage-detail"))
  end

  it "links the dashboard storage overview to the document file detail" do
    sign_in_as(admin_user)

    get admin_root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Storage使用量")
    expect(response.body).to include("DocumentFile 実体 detail")
    expect(response.body).to include(admin_storage_usage_document_files_path)
  end

  it "shows bounded document file detail with safe path previews" do
    existing_file = create(
      :document_file,
      document_version: version,
      file_name: "manual.pdf",
      content_type: "application/pdf",
      storage_key: "spec/storage-usage-detail/manual.pdf"
    )
    write_document_file(existing_file.storage_key, "x" * 2048)
    create(
      :document_file,
      document_version: version,
      file_name: "missing.pdf",
      content_type: "application/pdf",
      storage_key: "spec/storage-usage-detail/missing.pdf"
    )

    26.times do |index|
      storage_key = "spec/storage-usage-detail/extra-#{index}.txt"
      create(:document_file, document_version: version, file_name: "extra-#{index}.txt", storage_key: storage_key)
      write_document_file(storage_key, "extra")
    end

    sign_in_as(admin_user)

    get admin_storage_usage_document_files_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("DocumentFile 実体 storage detail")
    expect(page_text).to include("登録 DocumentFile: 28 件")
    expect(page_text).to include("表示中: #{StorageUsageSummary::DOCUMENT_FILE_DETAIL_LIMIT} 件")
    expect(page_text).to include("実体欠落: 1 件")
    expect(response.body).to include("STOR4418")
    expect(response.body).to include("Storage Project")
    expect(response.body).to include("Storage Manual")
    expect(response.body).to include(project_document_path(project, document.slug))
    expect(response.body).to include("manual.pdf")
    expect(response.body).to include("storage/document_files/spec/storage-usage-detail/manual.pdf")
    expect(response.body).to include("missing.pdf")
    expect(response.body).to include("storage/document_files/spec/storage-usage-detail/missing.pdf")
    expect(page_text).to include("表示は先頭#{StorageUsageSummary::DOCUMENT_FILE_DETAIL_LIMIT}件に限定しています。")
    expect(response.body).not_to include(Rails.root.to_s)
    expect(response.body).not_to include("https://storage.googleapis.com")
    expect(parsed_html.css('a').map { |link| link.text.squish }).not_to include("削除")
    expect(parsed_html.css('a').map { |link| link.text.squish }).not_to include("archive")
    expect(parsed_html.css('a').map { |link| link.text.squish }).not_to include("retention")
  end

  it "shows an empty state when no document files exist" do
    sign_in_as(admin_user)

    get admin_storage_usage_document_files_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("登録 DocumentFile: 0 件")
    expect(response.body).to include("DocumentFile 実体 detail はありません")
    expect(response.body).not_to include(Rails.root.to_s)
  end
end
