require "rails_helper"

RSpec.describe "Admin missing document files", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:version) { create(:document_version) }

  it "lets admins open missing file details from the dashboard" do
    file = create(
      :document_file,
      document_version: version,
      file_name: "missing-detail.txt",
      storage_key: "spec/admin-missing-document-files/missing-detail.txt"
    )

    sign_in_as(admin_user)

    get admin_root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("欠落ファイル詳細を開く")
    expect(response.body).to include(admin_missing_document_files_path)

    get admin_missing_document_files_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("欠落文書ファイル詳細")
    expect(response.body).to include(version.document.project.name)
    expect(response.body).to include(version.document.title)
    expect(response.body).to include(version.version_label)
    expect(response.body).to include(file.file_name)
    expect(response.body).to include(file.storage_key)
    expect(response.body).to include("storage/document_files/spec/admin-missing-document-files/missing-detail.txt")
  end

  it "keeps the details page admin-only" do
    sign_in_as(create(:user, :company_master_admin))
    get admin_missing_document_files_path
    expect(response).to have_http_status(:forbidden)

    sign_in_as(create(:user, :external))
    get admin_missing_document_files_path
    expect(response).to have_http_status(:forbidden)
  end

  it "shows an empty state when no document files are missing" do
    sign_in_as(admin_user)

    get admin_missing_document_files_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("実体ファイルの欠落は検出されていません。")
    expect(response.body).not_to include("Expected path")
  end

  it "bounds the detail list and does not expose destructive actions" do
    101.times do |index|
      create(
        :document_file,
        document_version: version,
        file_name: "missing-detail-#{index}.txt",
        storage_key: "spec/admin-missing-document-files/limited/missing-detail-#{index}.txt"
      )
    end

    sign_in_as(admin_user)

    get admin_missing_document_files_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("この詳細一覧は先頭100件まで表示します。")
    expect(response.body).to include("missing-detail-0.txt")
    expect(response.body).to include("missing-detail-99.txt")
    expect(response.body).not_to include("missing-detail-100.txt")
    expect(response.body).not_to include("削除")
    expect(response.body).not_to include("修復")
    expect(response.body).not_to include("CSV export")
  end
end
