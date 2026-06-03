require "rails_helper"

RSpec.describe "Admin dashboard", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:version) { create(:document_version) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def operation_summary
    parsed_html.at_css('[data-testid="operation-failure-summary"]')
  end

  def operation_summary_card(title)
    operation_summary.css("article").find { |node| node.text.include?(title) }
  end

  def operation_summary_hrefs
    operation_summary.css("a[href]").map { _1["href"] }
  end

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
    expect(response.body).to include("missing.txt")
    expect(response.body).to include("spec/admin-dashboard/missing.txt")
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

  it "shows operational failure entry points with scoped counts" do
    create_git_import_run!(status: :failed)
    create_git_import_run!(status: :skipped, repository_full_name: "example/skipped")
    create_git_import_run!(status: :imported, repository_full_name: "example/imported")
    create_generated_file_event!(status: :failed)
    create_generated_file_event!(status: :processed, path: "docs/processed.yml")
    create_generated_file_run!(status: :failed)
    create_generated_file_run!(status: :completed, job_id: "completed_job")
    create(:webhook_delivery, status: :failed)
    create(:webhook_delivery, status: :succeeded)
    warning_source = create_external_folder_sync_source!(name: "Warning source")
    create_external_folder_sync_run!(external_folder_sync_source: warning_source, status: :completed, summary_json: { "conflict_warnings_count" => 1 })
    create_external_folder_sync_source!(name: "Error source", last_error_message: "latest sync failed")
    create_external_folder_sync_source!(name: "Clean source")

    sign_in_as(admin_user)

    get admin_root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("運用失敗サマリー")
    expect(operation_summary_hrefs).to include(
      admin_git_import_runs_path,
      admin_generated_file_events_path(status: "failed"),
      admin_generated_file_runs_path(status: "failed"),
      admin_webhook_deliveries_path(status: "failed"),
      admin_external_folder_sync_sources_path
    )

    aggregate_failures "scoped operation cards" do
      expect(operation_summary_card("Git同期履歴").text).to include("2", "失敗/スキップ", "保存済み履歴全体")
      expect(operation_summary_card("生成ファイルイベント").text).to include("1", "失敗", "保存済みイベント全体")
      expect(operation_summary_card("生成ファイル実行履歴").text).to include("1", "失敗", "保存済み実行履歴全体")
      expect(operation_summary_card("Webhook送信履歴").text).to include("1", "失敗", "保存済み送信履歴全体")
      expect(operation_summary_card("外部フォルダ同期").text).to include("2", "要確認", "設定ごとの最新run/保存エラー")
    end
  end

  it "keeps operational failure entry points visible when there are no targets" do
    sign_in_as(admin_user)

    get admin_root_path

    expect(response).to have_http_status(:ok)
    expect(operation_summary.css("article").size).to eq(5)
    expect(operation_summary.text.scan("確認対象なし").size).to eq(5)
    expect(operation_summary_card("Git同期履歴").text).to include("0", "確認対象なし")
    expect(operation_summary_hrefs).to include(admin_generated_file_runs_path(status: "failed"))
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
    expect(response.body).to include("missing-0.txt")
    expect(response.body).to include("missing-19.txt")
    expect(response.body).not_to include("missing-20.txt")
  end

  def create_git_import_run!(attributes = {})
    defaults = {
      repository_full_name: "example/docs",
      branch: "main",
      source_path: "docs",
      status: :failed,
      started_at: 1.minute.ago,
      finished_at: Time.current
    }
    GitImportRun.create!(defaults.merge(attributes))
  end

  def create_generated_file_event!(attributes = {})
    path = attributes.fetch(:path, "docs/source.yml")
    operation = attributes.fetch(:operation, "update")
    event_source = attributes.fetch(:event_source, "spec")
    defaults = {
      event_key: GeneratedFileEvent.build_event_key(path:, operation:, event_source:),
      path:,
      operation:,
      event_source:,
      status: :pending,
      metadata: {},
      scheduled_at: 1.minute.from_now,
      last_seen_at: Time.current,
      occurrences_count: 1
    }
    GeneratedFileEvent.create!(defaults.merge(attributes))
  end

  def create_generated_file_run!(attributes = {})
    defaults = {
      job_id: "sample_job",
      generator: "sample_generator",
      output_writer: "filesystem",
      status: :completed,
      event_source: "spec",
      source_paths: ["source.yml"],
      changed_files: ["source.yml"],
      generated_paths: ["generated.md"],
      metadata: {},
      started_at: 1.minute.ago,
      finished_at: Time.current
    }
    GeneratedFileRun.create!(defaults.merge(attributes))
  end

  def create_external_folder_sync_source!(attributes = {})
    defaults = {
      project: create(:project),
      created_by: admin_user,
      provider: :google_drive,
      auth_type: :oauth_user,
      name: "Drive source",
      folder_url: "https://drive.google.com/drive/folders/spec-source",
      external_folder_id: "spec-source",
      sync_direction: :external_to_portal,
      conflict_policy: :manual,
      enabled: true,
      auth_config: {}.to_json
    }
    ExternalFolderSyncSource.create!(defaults.merge(attributes))
  end

  def create_external_folder_sync_run!(attributes = {})
    defaults = {
      status: :completed,
      mode: :dry_run,
      started_at: Time.current,
      summary_json: {}
    }
    ExternalFolderSyncRun.create!(defaults.merge(attributes))
  end
end
