require "rails_helper"
require "csv"

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

  def parsed_csv
    CSV.parse(response.body, headers: true)
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

  it "keeps the document file storage detail and CSV handoff admin-only" do
    sign_in_as(create(:user, :company_master_admin))
    get admin_storage_usage_document_files_path(format: :csv)
    expect(response).to have_http_status(:forbidden)

    sign_in_as(create(:user, :external))
    get admin_storage_usage_document_files_path(format: :csv)
    expect(response).to have_http_status(:forbidden)
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
    expect(response.body).to include(admin_storage_usage_document_files_path(format: :csv))
    expect(page_text).to include("CSV handoff")
    expect(page_text).to include("欠落ファイル詳細 CSV とは違い、容量・所有者・safe path の引き継ぎに閉じ")
    expect(page_text).to include("CSV handoff も同じ先頭#{StorageUsageSummary::DOCUMENT_FILE_DETAIL_LIMIT}件までです。")
    expect(response.body).not_to include(Rails.root.to_s)
    expect(response.body).not_to include("https://storage.googleapis.com")
    expect(parsed_html.css('a').map { |link| link.text.squish }).not_to include("削除")
    expect(parsed_html.css('a').map { |link| link.text.squish }).not_to include("archive")
    expect(parsed_html.css('a').map { |link| link.text.squish }).not_to include("retention")
  end

  it "exports the same bounded document file entries as a read-only CSV handoff" do
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

    get admin_storage_usage_document_files_path(format: :csv)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/csv")
    rows = parsed_csv
    expect(rows.size).to eq(StorageUsageSummary::DOCUMENT_FILE_DETAIL_LIMIT)
    expect(rows.headers).to include(
      "scope_status",
      "total_document_files",
      "displayed_document_files",
      "display_limit",
      "missing_document_files",
      "safe_relative_path",
      "read_only_note"
    )
    expect(rows.map { _1["scope_status"] }.uniq).to eq(["limited_to_bounded_entries"])
    expect(rows.map { _1["total_document_files"] }.uniq).to eq(["28"])
    expect(rows.map { _1["displayed_document_files"] }.uniq).to eq([StorageUsageSummary::DOCUMENT_FILE_DETAIL_LIMIT.to_s])
    expect(rows.map { _1["display_limit"] }.uniq).to eq([StorageUsageSummary::DOCUMENT_FILE_DETAIL_LIMIT.to_s])
    expect(rows.map { _1["missing_document_files"] }.uniq).to eq(["1"])

    manual_row = rows.find { _1["file_name"] == "manual.pdf" }
    expect(manual_row["project_code"]).to eq("STOR4418")
    expect(manual_row["project_name"]).to eq("Storage Project")
    expect(manual_row["document_title"]).to eq("Storage Manual")
    expect(manual_row["document_slug"]).to eq("storage-manual")
    expect(manual_row["safe_relative_path"]).to eq("storage/document_files/spec/storage-usage-detail/manual.pdf")
    expect(manual_row["file_count"]).to eq("1")
    expect(manual_row["missing_file_count"]).to eq("0")
    expect(manual_row["bytes"]).to eq("2048")
    expect(manual_row["read_only_note"]).to include("read-only handoff only")

    missing_row = rows.find { _1["file_name"] == "missing.pdf" }
    expect(missing_row["safe_relative_path"]).to eq("storage/document_files/spec/storage-usage-detail/missing.pdf")
    expect(missing_row["missing_file_count"]).to eq("1")
    expect(missing_row["bytes"]).to eq("0")
    expect(response.body).not_to include(Rails.root.to_s)
    expect(response.body).not_to include("https://storage.googleapis.com")
    expect(response.body).not_to include("signed_url")
    expect(response.body).not_to include("bucket")
  end

  it "exports a summary row for the empty CSV handoff state" do
    sign_in_as(admin_user)

    get admin_storage_usage_document_files_path(format: :csv)

    expect(response).to have_http_status(:ok)
    rows = parsed_csv
    expect(rows.size).to eq(1)
    row = rows.first
    expect(row["scope_status"]).to eq("no_entries")
    expect(row["total_document_files"]).to eq("0")
    expect(row["displayed_document_files"]).to eq("0")
    expect(row["display_limit"]).to eq(StorageUsageSummary::DOCUMENT_FILE_DETAIL_LIMIT.to_s)
    expect(row["read_only_note"]).to include("does not prove cleanup")
    expect(response.body).not_to include(Rails.root.to_s)
  end

  it "shows an empty state when no document files exist" do
    sign_in_as(admin_user)

    get admin_storage_usage_document_files_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("登録 DocumentFile: 0 件")
    expect(response.body).to include("DocumentFile 実体 detail はありません")
    expect(response.body).to include("CSV handoff でも 0 件状態を示す summary row だけを返します。")
    expect(response.body).not_to include(Rails.root.to_s)
  end
end
