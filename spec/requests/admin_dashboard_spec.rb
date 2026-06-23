require "rails_helper"

RSpec.describe "Admin dashboard", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:version) { create(:document_version) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def dashboard_section(title)
    parsed_html.css("section.card").find { |section| section.at_css("h2")&.text&.squish == title }
  end

  def dashboard_model_observation_card(label)
    dashboard_section("モデル観測").css(".metric-card").find { |card| card.at_css("h3")&.text&.squish == label }
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
    expect(response.body).to include("欠落ファイル詳細を開く")
    expect(response.body).to include(admin_missing_document_files_path)
    expect(response.body).to include("missing.txt")
    expect(response.body).to include("spec/admin-dashboard/missing.txt")
  end

  it "shows model observation counts and latest update cues for dashboard entries" do
    timestamp = Time.zone.local(2026, 6, 9, 10, 30, 0)
    project = create(:project, code: "DASH2594", name: "Dashboard Observation", updated_at: timestamp)

    sign_in_as(admin_user)

    get admin_root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("モデル観測")
    expect(response.body).to include("モデルブラウザを開く（全#{Admin::ModelBrowserCatalog.entries.size}件）")

    project_card_text = dashboard_model_observation_card("案件").text.squish
    permission_card_text = dashboard_model_observation_card("文書権限").text.squish

    expect(project_card_text).to include("公開単位となる案件の一覧です。")
    expect(project_card_text).to include("件数1")
    expect(project_card_text).to include("最終更新#{I18n.l(project.reload.updated_at, format: :short)}")
    expect(permission_card_text).to include("件数0")
    expect(permission_card_text).to include("最終更新-")
  end

  it "shows a read-only storage usage summary with follow-up cues" do
    latest_site_update = Time.zone.local(2026, 6, 22, 10, 15, 0)
    latest_import_update = Time.zone.local(2026, 6, 22, 11, 45, 0)
    summary = StorageUsageSummary::Result.new(
      areas: [
        StorageUsageSummary::Area.new(
          key: :document_files,
          label: "DocumentFile 実体",
          relative_path: "storage/document_files",
          description: "アップロード、ZIP/Git/外部同期で取り込まれた文書添付の正本",
          bytes: 1024,
          file_count: 2,
          breakdown_entries: [
            StorageUsageSummary::BreakdownEntry.new(
              relative_path: "storage/document_files/project-a",
              bytes: 1024,
              file_count: 2,
              latest_updated_at: latest_site_update
            )
          ]
        ),
        StorageUsageSummary::Area.new(
          key: :docs_sites,
          label: "Docs site build",
          relative_path: "storage/docs_sites",
          description: "Docusaurus などで生成した文書表示用 site artifact",
          bytes: 2048,
          file_count: 3,
          breakdown_entries: [
            StorageUsageSummary::BreakdownEntry.new(
              relative_path: "storage/docs_sites/project-alpha-site",
              bytes: 2048,
              file_count: 3,
              latest_updated_at: latest_site_update
            )
          ]
        ),
        StorageUsageSummary::Area.new(
          key: :imports,
          label: "Import staging",
          relative_path: "storage/imports",
          description: "ZIP / manual upload dry-run などの一時確認 artifact",
          bytes: 512,
          file_count: 1,
          breakdown_entries: [
            StorageUsageSummary::BreakdownEntry.new(
              relative_path: "storage/imports/manual-upload-42",
              bytes: 512,
              file_count: 1,
              latest_updated_at: latest_import_update
            )
          ]
        ),
        StorageUsageSummary::Area.new(
          key: :logs,
          label: "Log cache",
          relative_path: "storage/logs",
          description: "read-only に確認する一時 log cache",
          bytes: 256,
          file_count: 1,
          breakdown_entries: []
        )
      ]
    )
    allow(StorageUsageSummary).to receive(:new).and_return(instance_double(StorageUsageSummary, call: summary))

    sign_in_as(admin_user)

    get admin_root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Storage使用量")
    expect(response.body).to include("read-only")
    expect(response.body).to include("大きい内訳は各領域の直下項目を上位5件までに閉じた read-only preview")
    expect(response.body).to include("storage/document_files")
    expect(response.body).to include("storage/docs_sites")
    expect(response.body).to include("storage/imports")
    expect(response.body).to include("storage/logs")
    expect(response.body).to include("storage/docs_sites/project-alpha-site")
    expect(response.body).to include("storage/imports/manual-upload-42")
    expect(page_text).to include("最終更新: #{I18n.l(latest_site_update, format: :short)}")
    expect(page_text).to include("最終更新: #{I18n.l(latest_import_update, format: :short)}")
    expect(response.body).to include("削除、archive、cleanup、retention policy 決定、GCS API 連携はここでは行いません")
    expect(response.body).to include("次の確認先")
    expect(response.body).to include("欠落ファイル詳細")
    expect(response.body).to include(admin_missing_document_files_path)
    expect(response.body).to include("storage 運用方針")
    expect(response.body).to include("ファイル配信・storage運用方針.md")
    expect(response.body).to include("Docusaurus build runtime")
    expect(response.body).to include("docs/notes/docusaurus-build-runtime.md")
    expect(response.body).to include("manual upload dry-run")
    expect(response.body).to include(admin_file_upload_dry_runs_path)
    expect(response.body).to include("ZIP import")
    expect(response.body).to include(new_admin_zip_import_path)
    expect(response.body).to include("この行は read-only 集計です")
    expect(response.body).not_to include(Rails.root.to_s)
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

  it "shows operational failure entry summary with latest history cues" do
    project = create(:project)
    source = GitImportSource.create!(
      project: project,
      created_by: admin_user,
      provider: :github,
      repository_full_name: "example/private-docs",
      branch: "main",
      source_path: "docs",
      auth_type: :github_app,
      enabled: true
    )
    failed_git_run = GitImportRun.create!(
      git_import_source: source,
      provider: :github,
      import_mode: :pull,
      status: :failed,
      repository_full_name: "example/private-docs",
      branch: "main",
      source_path: "docs"
    )
    skipped_git_run = GitImportRun.create!(
      git_import_source: source,
      provider: :github,
      import_mode: :pull,
      status: :skipped,
      repository_full_name: "example/private-docs",
      branch: "main",
      source_path: "docs"
    )
    generated_run = GeneratedFileRun.create!(job_id: "docs-build", status: :failed)
    generated_event = GeneratedFileEvent.create!(
      event_key: "docs/runbook.md:update:spec",
      path: "docs/runbook.md",
      operation: "update",
      status: :failed,
      scheduled_at: 1.hour.ago,
      last_seen_at: Time.current
    )
    webhook_delivery = create(:webhook_delivery, status: :failed)
    sync_source = ExternalFolderSyncSource.create!(
      project: project,
      created_by: admin_user,
      provider: :google_drive,
      auth_type: :oauth_user,
      name: "Drive source",
      folder_url: "https://drive.google.com/drive/folders/spec-folder",
      external_folder_id: "spec-folder",
      sync_direction: :external_to_portal,
      conflict_policy: :manual,
      auth_config: "{}",
      enabled: true
    )
    external_sync_run = ExternalFolderSyncRun.create!(
      external_folder_sync_source: sync_source,
      status: :partial,
      mode: :dry_run,
      started_at: Time.current
    )
    latest_failure_at = 2.hours.ago
    failed_git_run.update!(updated_at: 3.hours.ago)
    skipped_git_run.update!(updated_at: latest_failure_at)
    generated_run.update!(updated_at: 4.hours.ago)
    generated_event.update!(updated_at: latest_failure_at)
    webhook_delivery.update!(updated_at: latest_failure_at)
    external_sync_run.update!(updated_at: latest_failure_at)

    sign_in_as(admin_user)

    get admin_root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("運用失敗入口")
    expect(response.body).to include("保存済み履歴の failed / skipped / partial 件数と、生成ファイルの継続失敗候補を分けて確認できます。")
    expect(response.body).to include("Git同期")
    expect(response.body).to include("failed: 1")
    expect(response.body).to include("skipped: 1")
    expect(response.body).to include(admin_git_import_runs_path)
    expect(response.body).to include("生成ファイル")
    expect(response.body).to include("実行履歴 failed: 1")
    expect(response.body).to include("イベント failed: 1")
    expect(page_text).to include("継続失敗候補: 0 件")
    expect(page_text).to include("保存済み failed 件数とは別の read-only 調査入口です。")
    expect(response.body).to include(admin_generated_file_runs_path(status: "failed"))
    expect(response.body).to include(admin_generated_file_events_path(status: "failed"))
    expect(response.body).to include("Webhook送信")
    expect(response.body).to include(admin_webhook_deliveries_path(status: "failed"))
    expect(response.body).to include("外部フォルダ同期")
    expect(response.body).to include("partial: 1")
    expect(response.body).to include(admin_external_folder_sync_sources_path(review: "errors"))
    expect(response.body).to include("対象履歴の最終更新")
    expect(response.body).to include("発生時刻や alert 発火時刻ではありません。")
    expect(response.body).to include(I18n.l(latest_failure_at, format: :short))
    expect(response.body).not_to include("古い失敗のみ")
    expect(response.body).to include("アプリ設定診断")
    expect(response.body).to include("文書ファイル健全性")
  end

  it "calls generated run alert candidates with a bounded dashboard query window" do
    alert_candidate_service = instance_double(GeneratedFiles::RunFailureAlertCandidates, call: [])
    expect(GeneratedFiles::RunFailureAlertCandidates).to receive(:new).with(
      limit: Admin::DashboardController::GENERATED_FILE_ALERT_CANDIDATE_LIMIT,
      lookback_limit: Admin::DashboardController::GENERATED_FILE_ALERT_CANDIDATE_LOOKBACK_LIMIT
    ).and_return(alert_candidate_service)

    sign_in_as(admin_user)

    get admin_root_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("継続失敗候補: 0 件")
  end

  it "shows generated file consecutive failure alert candidates without showing resolved streaks" do
    latest_failure_at = 30.minutes.ago.change(usec: 0)
    [latest_failure_at, 45.minutes.ago, 1.hour.ago].each_with_index do |started_at, index|
      GeneratedFileRun.create!(
        job_id: "docs-build",
        generator: "docusaurus",
        output_writer: "filesystem",
        event_source: "schedule",
        status: :failed,
        started_at: started_at,
        finished_at: started_at + 1.minute,
        error_message: index.zero? ? "latest docusaurus timeout while building a very long generated file batch" : "older failure"
      )
    end
    GeneratedFileRun.create!(
      job_id: "docs-build",
      generator: "docusaurus",
      output_writer: "filesystem",
      event_source: "schedule",
      status: :completed,
      started_at: 2.hours.ago,
      finished_at: 2.hours.ago + 1.minute
    )
    GeneratedFileRun.create!(
      job_id: "fixed-job",
      generator: "docusaurus",
      output_writer: "filesystem",
      event_source: "schedule",
      status: :completed,
      started_at: 5.minutes.ago,
      finished_at: 4.minutes.ago
    )
    3.times do |index|
      GeneratedFileRun.create!(
        job_id: "fixed-job",
        generator: "docusaurus",
        output_writer: "filesystem",
        event_source: "schedule",
        status: :failed,
        started_at: 2.hours.ago - index.minutes,
        finished_at: 2.hours.ago - index.minutes + 1.minute,
        error_message: "resolved failure"
      )
    end

    sign_in_as(admin_user)

    get admin_root_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("継続失敗候補: 1 件")
    expect(page_text).to include("保存済み failed 件数とは別の read-only 調査入口です。")
    expect(page_text).to include("最新 run が同じ identity で連続 failed のものだけを表示します。")
    expect(page_text).to include("docs-build")
    expect(page_text).to include("docusaurus / filesystem / schedule")
    expect(page_text).to include("連続失敗: 3 件")
    expect(response.body).to include(I18n.l(latest_failure_at + 1.minute, format: :short))
    expect(page_text).to include("latest docusaurus timeout")
    expect(response.body).to include(admin_generated_file_runs_path(status: "failed"))
    expect(page_text).not_to include("fixed-job")
    expect(page_text).not_to include("resolved failure")
  end

  it "marks operational failure entries as stale when only old failures remain" do
    project = create(:project)
    source = GitImportSource.create!(
      project: project,
      created_by: admin_user,
      provider: :github,
      repository_full_name: "example/private-docs",
      branch: "main",
      source_path: "docs",
      auth_type: :github_app,
      enabled: true
    )
    old_failure_at = 8.days.ago
    git_run = GitImportRun.create!(
      git_import_source: source,
      provider: :github,
      import_mode: :pull,
      status: :failed,
      repository_full_name: "example/private-docs",
      branch: "main",
      source_path: "docs"
    )
    git_run.update!(updated_at: old_failure_at)

    sign_in_as(admin_user)

    get admin_root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("対象履歴の最終更新")
    expect(response.body).to include(I18n.l(old_failure_at, format: :short))
    expect(response.body).to include("古い失敗のみ")
    expect(response.body).to include("7日より古い対象履歴だけが残っています")
  end

  it "shows zero-count operational failure entries without freshness cues when there is no saved failure data" do
    sign_in_as(admin_user)

    get admin_root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("運用失敗入口")
    expect(response.body).to include("Git同期")
    expect(response.body).to include("failed: 0")
    expect(response.body).to include("skipped: 0")
    expect(response.body).to include("実行履歴 failed: 0")
    expect(response.body).to include("イベント failed: 0")
    expect(page_text).to include("継続失敗候補: 0 件")
    expect(page_text).to include("保存済み failed 件数とは別の read-only 調査入口です。")
    expect(response.body).to include("最新 run が連続失敗している候補はありません。")
    expect(response.body).to include("partial: 0")
    expect(response.body).not_to include("対象履歴の最終更新")
    expect(response.body).not_to include("古い失敗のみ")
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
