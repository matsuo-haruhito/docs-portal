class Admin::ModelBrowserCatalog
  Entry = Data.define(:key, :label, :description, :model_class, :summary_fields, :index_path_helper)

  ENTRIES = [
    Entry.new("companies", "会社", "会社マスタと所属の起点です。", Company, %i[public_id name updated_at], :admin_companies_path),
    Entry.new("users", "ユーザー", "利用者種別と会社所属を確認します。", User, %i[public_id name email_address user_type active updated_at], :admin_users_path),
    Entry.new("projects", "案件", "公開単位となる案件の一覧です。", Project, %i[code name company_id active updated_at], :admin_projects_path),
    Entry.new("project_memberships", "案件所属", "社外ユーザーの案件到達条件です。", ProjectMembership, %i[public_id project_id user_id role updated_at], :admin_project_memberships_path),
    Entry.new("documents", "文書", "公開制御と最新版参照の中核です。", Document, %i[public_id title slug category visibility_policy importance_level updated_at], :admin_documents_path),
    Entry.new("document_versions", "文書版", "各版の公開状態とビルド情報です。", DocumentVersion, %i[public_id version_label status source_commit_hash published_at updated_at], nil),
    Entry.new("document_files", "文書ファイル", "添付・原本ファイルの保存情報です。", DocumentFile, %i[public_id file_name content_type file_size scan_status updated_at], nil),
    Entry.new("document_permissions", "文書権限", "社外ユーザー向けの閲覧・ダウンロード権限です。", DocumentPermission, %i[public_id document_id user_id company_id access_level updated_at], :admin_document_permissions_path),
    Entry.new("document_sets", "文書セット", "用途別にまとめた文書の組み合わせです。", DocumentSet, %i[public_id name internal_only updated_at], :admin_document_sets_path),
    Entry.new("document_catalogs", "文書カタログ", "案件配下の文書一覧です。", DocumentCatalog, %i[public_id name internal_only updated_at], nil),
    Entry.new("consent_terms", "同意文面", "利用前同意のマスタです。", ConsentTerm, %i[public_id title term_kind version active updated_at], :admin_consent_terms_path),
    Entry.new("project_consent_settings", "案件同意設定", "案件ごとの同意要件を管理します。", ProjectConsentSetting, %i[project_id consent_term_id required_on_first_view required_on_download updated_at], :admin_project_consent_settings_path),
    Entry.new("access_requests", "アクセス申請", "閲覧・ダウンロード申請の状態を追います。", AccessRequest, %i[public_id requestable_type requested_access_level status updated_at], :admin_access_requests_path),
    Entry.new("access_logs", "監査ログ", "表示・ダウンロードの操作記録です。", AccessLog, %i[public_id action_type target_type accessed_at updated_at], :admin_access_logs_path),
    Entry.new("document_bookmarks", "文書ショートカット", "お気に入りと後で読むの保存です。", DocumentBookmark, %i[public_id bookmark_type user_id document_id updated_at], nil),
    Entry.new("document_approval_requests", "確認依頼", "文書確認フローの依頼記録です。", DocumentApprovalRequest, %i[public_id status requester_id approver_id updated_at], nil),
    Entry.new("git_import_sources", "Git連携", "同期元の定義です。", GitImportSource, %i[public_id name repository_url branch active updated_at], :admin_git_import_sources_path),
    Entry.new("git_import_runs", "Git同期履歴", "Git取り込み実行の履歴です。", GitImportRun, %i[public_id status started_at finished_at updated_at], :admin_git_import_runs_path),
    Entry.new("external_folder_sync_sources", "外部フォルダ同期", "Google Driveなどの外部フォルダ同期元です。", ExternalFolderSyncSource, %i[public_id provider name external_folder_id enabled last_synced_at updated_at], :admin_external_folder_sync_sources_path),
    Entry.new("external_folder_sync_runs", "外部フォルダ同期履歴", "外部フォルダ同期の実行履歴です。", ExternalFolderSyncRun, %i[public_id mode status started_at finished_at updated_at], nil),
    Entry.new("external_folder_sync_items", "外部フォルダ同期アイテム", "外部ファイルとポータル文書の対応関係です。", ExternalFolderSyncItem, %i[public_id external_item_id sync_status path updated_at], nil),
    Entry.new("external_folder_sync_subscriptions", "外部フォルダ同期購読", "Google Drive / SharePoint の変更通知購読です。", ExternalFolderSyncSubscription, %i[public_id provider status provider_subscription_id provider_channel_id expires_at updated_at], nil),
    Entry.new("external_folder_sync_webhook_events", "外部フォルダ同期Webhook受信", "外部ストレージから受信した変更通知です。", ExternalFolderSyncWebhookEvent, %i[public_id provider status event_key received_at updated_at], nil),
    Entry.new("import_dry_runs", "インポート事前確認", "保存付きインポート確認の記録です。", ImportDryRun, %i[public_id import_mode status source_commit_hash updated_at], nil),
    Entry.new("bulk_edit_dry_runs", "一括編集事前確認", "文書一括変更の事前確認記録です。", BulkEditDryRun, %i[public_id operation_type status updated_at], nil),
    Entry.new("webhook_endpoints", "Webhook", "外部通知先の定義です。", WebhookEndpoint, %i[public_id name active event_types updated_at], :admin_webhook_endpoints_path),
    Entry.new("webhook_deliveries", "Webhook配信", "Webhook送信履歴です。", WebhookDelivery, %i[public_id status response_status delivered_at updated_at], nil)
  ].freeze

  class << self
    def entries
      ENTRIES
    end

    def fetch!(key)
      entries.find { _1.key == key.to_s } || raise(ActiveRecord::RecordNotFound, "Model browser entry not found: #{key}")
    end
  end
end
