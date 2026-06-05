require "rails_helper"

RSpec.describe "Admin dashboard", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:version) { create(:document_version) }

  it "shows document file health summary to internal admins" do
    DocumentFile.create!(
      document_version: version,
      file_name: "missing.txt",
      content_type: "text/plain",
      storage_key: "spec/admin-dashboard/missing.txt",
      file_size: 0
    )

    sign_in_as(admin_user)

    get admin_root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("文書ファイル健全性")
    expect(response.body).to include("モデルブラウザ")
    expect(response.body).to include("欠落ファイル詳細を開く")
    expect(response.body).to include(admin_missing_document_files_path)
    expect(response.body).to include("missing.txt")
    expect(response.body).to include("spec/admin-dashboard/missing.txt")
  end

  it "shows a read-only storage usage summary" do
    summary = StorageUsageSummary::Result.new(
      areas: [
        StorageUsageSummary::Area.new(
          key: :document_files,
          label: "DocumentFile 実体",
          relative_path: "storage/document_files",
          description: "アップロード、ZIP/Git/外部同期で取り込まれた文書添付の正本",
          bytes: 1024,
          file_count: 2
        ),
        StorageUsageSummary::Area.new(
          key: :docs_sites,
          label: "Docs site build",
          relative_path: "storage/docs_sites",
          description: "Docusaurus などで生成した文書表示用 site artifact",
          bytes: 2048,
          file_count: 3
        ),
        StorageUsageSummary::Area.new(
          key: :imports,
          label: "Import staging",
          relative_path: "storage/imports",
          description: "ZIP / manual upload dry-run などの一時確認 artifact",
          bytes: 512,
          file_count: 1
        )
      ]
    )
    allow(StorageUsageSummary).to receive(:new).and_return(instance_double(StorageUsageSummary, call: summary))

    sign_in_as(admin_user)

    get admin_root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Storage使用量")
    expect(response.body).to include("read-only")
    expect(response.body).to include("storage/document_files")
    expect(response.body).to include("storage/docs_sites")
    expect(response.body).to include("storage/imports")
    expect(response.body).to include("削除、archive、cleanup、retention policy 決定、GCS API 連携はここでは行いません")
  end

  it "links configuration diagnostics to the relevant runbooks" do
    sign_in_as(admin_user)

    get admin_root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("アプリ設定診断")
    expect(response.body).to include("環境変数・compose")
    expect(response.body).to include("ローカルセットアップと環境変数.md")
    expect(response.body).to include("Docusaurus / Kroki")
    expect(response.body).to include("docs/notes/docusaurus-build-runtime.md")
    expect(response.body).to include("storage 運用方針")
    expect(response.body).to include("ファイル配信・storage運用方針.md")
    expect(response.body).to include("管理ダッシュボード runbook")
    expect(response.body).to include("管理ダッシュボード・モデルブラウザ運用runbook.md")
  end

  it "explains that document file health details are limited when more files are missing" do
    21.times do |index|
      create(
        :document_file,
        document_version: version,
        file_name: "missing-#{index}.txt",
        storage_key: "spec/admin-dashboard/limited/missing-#{index}.txt"
      )
    end

    sign_in_as(admin_user)

    get admin_root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("登録ファイル数")
    expect(response.body).to include("実体欠落")
    expect(response.body).to include("欠落一覧は先頭20件のみ表示しています。")
    expect(response.body).to include("全件確認は詳細一覧または storage 側の調査で行ってください。")
    expect(response.body).to include("missing-0.txt")
    expect(response.body).to include("missing-19.txt")
    expect(response.body).not_to include("missing-20.txt")
  end
end
