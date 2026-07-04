#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"

MAINTENANCE_ROUTE_INVENTORY_REPO_ROOT = Pathname.new(File.expand_path("../..", __dir__))

MAINTENANCE_ROUTE_INVENTORY_FILES = {
  routes: MAINTENANCE_ROUTE_INVENTORY_REPO_ROOT.join("config/routes.rb"),
  docs: MAINTENANCE_ROUTE_INVENTORY_REPO_ROOT.join("docs/本番運用・インフラ前提.md")
}.freeze

MAINTENANCE_ROUTE_INVENTORY_ROUTE_SIGNALS = [
  "post :retry_run, on: :member",
  "post :retry_failed, on: :collection",
  "post :retry_dispatch, on: :member",
  "post :sync_definitions, on: :collection",
  "post :request_run, on: :member",
  "post :sync, on: :member",
  "post :dry_run, on: :member",
  "post :apply, on: :member",
  "post :force_apply, on: :member",
  "post :enqueue, on: :member",
  "post :subscribe, on: :member",
  "delete :unsubscribe, on: :member",
  "patch :archive, on: :member",
  "patch :restore, on: :member",
  "post :handoff, on: :collection",
  "resources :webhook_endpoints, except: %i[show new], param: :public_id",
  "resources :read_confirmations, only: %i[create destroy], param: :public_id",
  "resources :access_requests, only: %i[index create], param: :public_id",
  "post :cancel, on: :member",
  "resources :document_approval_requests, only: %i[index show update], param: :public_id",
  "resource :document_zip, only: [:create], controller: \"project_document_zips\"",
  "resource :rollback, only: [:create], controller: \"document_version_rollbacks\""
].freeze

MAINTENANCE_ROUTE_INVENTORY_ALLOWLIST_SIGNALS = [
  "get \"storage_usage/document_files\", to: \"storage_usage#document_files\"",
  "get \"storage_usage/docs_sites\", to: \"storage_usage#docs_sites\"",
  "get \"storage_usage/imports\", to: \"storage_usage#imports\"",
  "get :failure_alert_handoff, on: :collection",
  "get :pending_handoff, on: :collection",
  "get :lifecycle_handoff, on: :collection",
  "post \"codeblock_dry_run\", to: \"api_specifications#codeblock_dry_run\", as: :codeblock_dry_run",
  "post \"document_tree_all\", to: \"projects#document_tree_all\"",
  "match \"document_detail_tree\", to: \"projects#document_detail_tree\""
].freeze

MAINTENANCE_ROUTE_INVENTORY_DOC_SIGNALS = [
  "### 変更系操作 inventory",
  "ここに載っているだけでは停止済みを意味しません。",
  "`current` は既存 runbook で確認できる読み方、`候補` は個別 Issue / PR で停止可否を決める対象、`要判断` は docs だけでは停止方針を確定しない対象です。",
  "| 生成ファイル再実行 | `admin/generated_file_runs#retry_run` / `#retry_failed` | current。",
  "| 生成ファイルイベント再送 | `admin/generated_file_events#retry_dispatch` / `#retry_failed` | 候補。",
  "| API 仕様 build | `admin/api_specifications#retry_build` | current。`READ_ONLY_MAINTENANCE` 中は表示時の stale build enqueue、手動 `retry_build`、`site` 表示時の stale build enqueue を開始せず、生成済み HTML、表示状態、Build manifest、主要ページとsource、直近build履歴は read-only に確認できる。`codeblock_dry_run` は build 起動とは別 surface として扱う。",
  "| Webhook 再送 | `admin/webhook_deliveries#retry_dispatch` / `#retry_failed` | 候補。",
  "| 定期ジョブ操作 | `admin/recurring_job_schedules#sync_definitions` / `#request_run` | 要判断。",
  "| Git 手動同期 | `admin/git_import_sources#sync` | 候補。",
  "| 外部フォルダ同期 | `admin/external_folder_sync_sources#dry_run` / `#apply` / `#force_apply` / `#enqueue` / `#subscribe` / `#unsubscribe` / `#recheck_metadata` | 要判断。",
  "| アクセス申請 | `access_requests#create` / `#cancel`, `admin/access_requests#update` | 要判断。",
  "| 既読確認 | `read_confirmations#create` / `#destroy` | current。",
  "| 確認依頼 | `document_approval_requests#create` / `#update` / `#cancel` | current。確認依頼の新規作成と pending 依頼の OK / Cancel は `READ_ONLY_MAINTENANCE` 中に停止し、一覧・detail・requester / approver filter は read-only に残す。",
  "| TreeView / 文書 detail tree | `projects#document_tree_all` / `#document_detail_tree` | read-only POST。",
  "| 手動アップロード UI flow | `document_uploads#create`, `document_version_upload_reviews#create` | current。",
  "手動アップロード候補の作成と upload review の `OK` / `NG` は `READ_ONLY_MAINTENANCE` 中に停止し",
  "internal upload API / ZIP import / artifact import とは別に扱う。",
  "| 手動アップロード / import | `document_uploads#create`, `document_version_upload_reviews#create`, `api/internal/*_uploads#create`, `api/internal/artifact_imports#create` | 候補。combined inventory signal として残し",
  "| internal upload / import API | `api/internal/*_uploads#create`, `api/internal/artifact_imports#create` | 候補。",
  "手動アップロード UI flow の current support と混同しない。",
  "| 文書版 rollback / 文書状態変更 | `document_version_rollbacks#create`, `admin/documents#archive` / `#restore`, `admin/bulk_edit_dry_runs#handoff` / `#update` | 要判断。",
  "| 軽量な利用者操作 | `document_bookmarks#create` / `#destroy` / `#move_to_favorite`, `document_review_comments#create` / `#update`, `document_delivery_logs#create` / `#update` | 要判断。",
  "`current` として扱うのは、controller guard、request spec、関連 runbook の current support が揃っている操作だけです。",
  "maintenance mode を完全停止や全変更系停止として読まないようにします。"
].freeze

maintenance_route_inventory_errors = []

MAINTENANCE_ROUTE_INVENTORY_FILES.each do |label, path|
  maintenance_route_inventory_errors << "#{label}: missing file #{path}" unless path.file?
end

if maintenance_route_inventory_errors.empty?
  routes_content = MAINTENANCE_ROUTE_INVENTORY_FILES.fetch(:routes).read
  docs_content = MAINTENANCE_ROUTE_INVENTORY_FILES.fetch(:docs).read

  MAINTENANCE_ROUTE_INVENTORY_ROUTE_SIGNALS.each do |expected_text|
    next if routes_content.include?(expected_text)

    maintenance_route_inventory_errors << "config/routes.rb: missing representative mutation route signal: #{expected_text.inspect}"
  end

  MAINTENANCE_ROUTE_INVENTORY_ALLOWLIST_SIGNALS.each do |expected_text|
    next if routes_content.include?(expected_text)

    maintenance_route_inventory_errors << "config/routes.rb: missing read-only/dry-run allowlist route signal: #{expected_text.inspect}"
  end

  MAINTENANCE_ROUTE_INVENTORY_DOC_SIGNALS.each do |expected_text|
    next if docs_content.include?(expected_text)

    maintenance_route_inventory_errors << "docs/本番運用・インフラ前提.md: missing maintenance route inventory signal: #{expected_text.inspect}"
  end
end

if maintenance_route_inventory_errors.any?
  warn "Maintenance route inventory guard failed:"
  maintenance_route_inventory_errors.each { |error| warn "- #{error}" }
  exit 1
end

puts "Maintenance route inventory guard passed."
