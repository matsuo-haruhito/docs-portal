# frozen_string_literal: true

# Screenshots 撮影用の追加 seed データ。
# routes.rb から自動発見された admin 画面の show/edit が撮影できるよう、
# 各リソースに最低1件のレコードを投入する。

module SeedSupport
  class ScreenshotSeedData
    def run
      ActiveRecord::Base.transaction do
        seed_consent_terms
        seed_project_consent_settings
        seed_git_import_sources
        seed_generated_file_events
        seed_generated_file_runs
        seed_import_dry_runs
        seed_microsoft_graph_connections
        seed_external_folder_sync_sources
        seed_document_sets
        seed_document_catalogs
        seed_webhook_endpoints_and_deliveries
        seed_access_requests
      end
    end

    private

    def admin_user
      @admin_user ||= User.find_by!(email_address: "admin@example.com")
    end

    def first_project
      @first_project ||= Project.first!
    end

    def first_document
      @first_document ||= Document.first!
    end

    def first_version
      @first_version ||= DocumentVersion.first!
    end

    def external_user
      @external_user ||= User.find_by!(user_type: :external)
    end

    def now
      @now ||= Time.current
    end

    def seed_consent_terms
      return if ConsentTerm.exists?

      ConsentTerm.create!(
        public_id: "cterm_screenshot_001",
        title: "文書閲覧に関する注意事項",
        version_label: "v1.0",
        body: "本ポータルで閲覧する文書は社外秘です。第三者への開示を禁止します。",
        consent_scope: 0,
        requirement_timing: 0,
        active: true
      )
    end

    def seed_project_consent_settings
      return if ProjectConsentSetting.exists?

      consent_term = ConsentTerm.first!
      ProjectConsentSetting.create!(
        public_id: "pcs_screenshot_001",
        project: first_project,
        consent_term: consent_term,
        required_on: 0,
        enabled: true
      )
    end

    def seed_git_import_sources
      return if GitImportSource.exists?

      GitImportSource.create!(
        public_id: "gis_screenshot_001",
        project: first_project,
        repository_full_name: "example-org/docs-repository",
        branch: "main",
        source_path: "docs",
        provider: 0,
        auth_type: 0,
        enabled: true,
        created_by: admin_user
      )
    end

    def seed_generated_file_events
      return if GeneratedFileEvent.exists?

      GeneratedFileEvent.create!(
        public_id: "gfe_screenshot_001",
        event_key: "screenshot-seed-event-001",
        operation: "generate",
        path: "storage/docs_sites/sample/index.html",
        status: 2, # processed
        scheduled_at: 1.hour.ago,
        last_seen_at: 30.minutes.ago,
        processed_at: 30.minutes.ago
      )
    end

    def seed_generated_file_runs
      return if GeneratedFileRun.exists?

      GeneratedFileRun.create!(
        public_id: "gfr_screenshot_001",
        job_id: "screenshot-seed-run-001",
        status: 2, # completed
        generator: "DocusaurusSiteRenderer",
        event_source: "git_import",
        started_at: 1.hour.ago,
        finished_at: 50.minutes.ago,
        source_paths: ["docs/guide.md"],
        generated_paths: ["storage/docs_sites/sample/index.html"],
        changed_files: ["index.html"]
      )
    end

    def seed_import_dry_runs
      return if ImportDryRun.where(import_mode: :manual_upload).exists?

      ImportDryRun.create!(
        public_id: "idr_screenshot_002",
        project: first_project,
        created_by: admin_user,
        import_mode: 3, # manual_upload
        status: 0, # analyzed (not yet confirmed)
        summary_json: { total: 3, created: 2, updated: 1, skipped: 0 },
        result_json: { documents: [{ slug: "sample", action: "create" }] },
        errors_json: [],
        warnings_json: [],
        expires_at: 1.day.from_now
      )
    end

    def seed_microsoft_graph_connections
      return if MicrosoftGraphConnection.exists?

      MicrosoftGraphConnection.create!(
        public_id: "mgc_screenshot_001",
        project: first_project,
        name: "サンプル SharePoint 接続",
        tenant_id: "00000000-0000-0000-0000-000000000001",
        client_id: "00000000-0000-0000-0000-000000000002",
        client_secret: "screenshot-seed-secret",
        site_id: "example.sharepoint.com,site-id",
        drive_id: "drive-id-001",
        auth_type: 0,
        enabled: true,
        preview_selected: false,
        created_by: admin_user
      )
    end

    def seed_external_folder_sync_sources
      return if ExternalFolderSyncSource.exists?

      ExternalFolderSyncSource.create!(
        public_id: "efss_screenshot_001",
        project: first_project,
        name: "サンプル Google Drive 同期",
        provider: 0,
        auth_type: 0,
        auth_config: "{}",
        folder_url: "https://drive.google.com/drive/folders/sample-folder-id",
        external_folder_id: "sample-folder-id",
        external_folder_path: "/共有ドライブ/文書管理",
        enabled: true,
        created_by: admin_user
      )
    end

    def seed_document_sets
      return if DocumentSet.exists?

      doc_set = DocumentSet.create!(
        public_id: "dset_screenshot_001",
        project: first_project,
        name: "初回納品セット",
        description: "初回納品に含める文書一式",
        set_type: 0,
        sort_order: 1,
        visibility_policy: 0,
        created_by: admin_user
      )

      DocumentSetItem.create!(
        document_set: doc_set,
        document: first_document,
        document_version: first_version,
        sort_order: 1,
        note: "最新版を含める"
      )
    end

    def seed_document_catalogs
      return if DocumentCatalog.exists?

      catalog = DocumentCatalog.create!(
        public_id: "dcat_screenshot_001",
        project: first_project,
        name: "操作マニュアル集",
        description: "利用者向け操作マニュアルをまとめたカタログ",
        audience_type: 0,
        sort_order: 1,
        visibility_policy: 0
      )

      DocumentCatalogItem.create!(
        document_catalog: catalog,
        document: first_document,
        sort_order: 1,
        note: "基本操作ガイド"
      )
    end

    def seed_webhook_endpoints_and_deliveries
      endpoint = if WebhookEndpoint.exists?
        WebhookEndpoint.first!
      else
        WebhookEndpoint.create!(
          public_id: "whe_screenshot_001",
          name: "サンプル Webhook",
          target_url: "https://example.com/webhooks/docs-portal",
          event_types: ["document_published", "document_updated"],
          active: true,
          secret_token: "whsec_screenshot_sample_token"
        )
      end

      return if WebhookDelivery.exists?

      event = NotificationEvent.first || NotificationEvent.create!(
        public_id: "nevt_screenshot_001",
        title: "文書「サンプル」が公開されました",
        event_type: 0,
        occurred_at: 1.hour.ago,
        project: first_project,
        document: first_document,
        document_version: first_version,
        actor_user: admin_user
      )

      WebhookDelivery.create!(
        public_id: "whd_screenshot_001",
        webhook_endpoint: endpoint,
        notification_event: event,
        event_type: "document_published",
        target_url: endpoint.target_url,
        request_body: '{"event":"document_published","document_id":"doc_001"}',
        response_status: 200,
        response_body: '{"ok":true}',
        status: 1, # success
        sent_at: 1.hour.ago
      )
    end

    def seed_access_requests
      return if AccessRequest.exists?

      AccessRequest.create!(
        public_id: "areq_screenshot_001",
        requester: external_user,
        requestable: first_project,
        requested_access_level: 0,
        reason: "案件の文書を閲覧したいため",
        status: 0 # pending
      )
    end
  end
end
