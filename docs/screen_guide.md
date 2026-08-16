# 画面仕様ガイド

> このドキュメントは `npx tsx script/generate_screen_docs.ts` で自動生成されています。
> 正本は `script/screenshot_scenarios.ts`（明示的シナリオ）と
> `capture_screenshots.ts` が routes.rb から自動生成するシナリオです。
> スクリーンショットは `docs/screenshots/` を参照しています。

---

## 目次

### 公開側

- [利用者ダッシュボード](#利用者ダッシュボード)
- [案件文書ツリー](#案件文書ツリー)
- [ログイン](#ログイン)

### 管理画面

- [管理ダッシュボード](#管理ダッシュボード)
- [診断](#診断)
- [文書マスタ一覧](#文書マスタ一覧)
- [案件一覧](#案件一覧)
- [文書権限一覧](#文書権限一覧)
- [文書セット一覧](#文書セット一覧)
- [document_catalogs 一覧](#documentcatalogs-一覧)
- [companies 一覧](#companies-一覧)
- [users 一覧](#users-一覧)
- [project_memberships 一覧](#projectmemberships-一覧)
- [consent_terms 一覧](#consentterms-一覧)
- [project_consent_settings 一覧](#projectconsentsettings-一覧)
- [Git連携設定一覧](#git連携設定一覧)
- [git_import_runs 一覧](#gitimportruns-一覧)
- [外部フォルダ同期設定一覧](#外部フォルダ同期設定一覧)
- [microsoft_graph_connections 一覧](#microsoftgraphconnections-一覧)
- [zip_imports 新規作成](#zipimports-新規作成)
- [file_upload_dry_runs 一覧](#fileuploaddryruns-一覧)
- [bulk_edit_dry_runs 新規作成](#bulkeditdryruns-新規作成)
- [missing_document_files 詳細](#missingdocumentfiles-詳細)

### システム管理

- [Webhook設定一覧](#webhook設定一覧)
- [webhook_deliveries 一覧](#webhookdeliveries-一覧)
- [アクセスログ](#アクセスログ)
- [access_requests 一覧](#accessrequests-一覧)
- [document_usage_reports 一覧](#documentusagereports-一覧)
- [read_confirmations 一覧](#readconfirmations-一覧)
- [recurring_job_schedules 一覧](#recurringjobschedules-一覧)
- [generated_file_events 一覧](#generatedfileevents-一覧)
- [generated_file_runs 一覧](#generatedfileruns-一覧)

---

## 公開側

### 利用者ダッシュボード

**用途:** 外部利用者がアクセス可能な案件と文書を確認する

#### メイン画面

**この画面での操作:**

- アクセス可能な案件の一覧確認
- 最近閲覧した文書へのアクセス
- お気に入り・後で読むショートカット

> ⏳ このシナリオは未撮影です（deferred）

### 案件文書ツリー

**用途:** 外部利用者が案件内の文書ツリーから目的の文書を探す

#### メイン画面

**この画面での操作:**

- 文書ツリーの展開・折りたたみ
- 文書の選択と本文表示
- サイドバーのリサイズ・折りたたみ

> ⏳ このシナリオは未撮影です（deferred）

### ログイン

**用途:** 未ログインの利用者がメールアドレスとパスワードを入力してポータルへ進む

#### 新規作成画面

**この画面での操作:**

- メールアドレスとパスワードを入力してログイン

![新規作成画面](screenshots/session-new.png)

## 管理画面

### 管理ダッシュボード

**用途:** 管理者が管理画面トップで全体状況を確認する

#### メイン画面

**この画面での操作:**

- 要対応事項の確認
- 各管理機能への導線

![メイン画面](screenshots/admin-dashboard.png)

### 診断

**用途:** 管理者がシステム構成と要対応事項を診断する

#### 一覧画面

**この画面での操作:**

- 環境設定の整合性確認
- 要対応事項の確認と対処導線

![一覧画面](screenshots/admin-diagnostics-index.png)

### 文書マスタ一覧

**用途:** 管理者が文書マスタを検索・フィルタして対象文書を確認する

#### 一覧画面

**この画面での操作:**

- 案件・状態・種別による検索とフィルタ
- 列設定のカスタマイズ
- CSV出力
- 文書のアーカイブ・復元操作

![一覧画面](screenshots/admin-documents-index.png)

#### 編集画面

![編集画面](screenshots/admin-documents-edit.png)

### 案件一覧

**用途:** 管理者が案件を検索・管理する

#### 一覧画面

**この画面での操作:**

- 会社・案件名による検索
- 案件の新規作成・編集

![一覧画面](screenshots/admin-projects-index.png)

#### 編集画面

![編集画面](screenshots/admin-projects-edit.png)

### 文書権限一覧

**用途:** 管理者が文書権限の付与状況を確認・管理する

#### 一覧画面

**この画面での操作:**

- 案件・文書・会社・ユーザーによるフィルタ
- 権限の追加・変更・削除
- CSV出力

![一覧画面](screenshots/admin-document-permissions-index.png)

#### 編集画面

![編集画面](screenshots/admin-document-permissions-edit.png)

### 文書セット一覧

**用途:** 管理者が文書セットを確認・管理する

#### 一覧画面

**この画面での操作:**

- 文書セットの作成・編集・削除
- 対象文書の管理（固定版 / 最新版）

![一覧画面](screenshots/admin-document-sets-index.png)

#### 編集画面

![編集画面](screenshots/admin-document-sets-edit.png)

### document_catalogs 一覧

**用途:** 管理者がdocument_catalogsの一覧画面で業務情報を確認する

#### 一覧画面

![一覧画面](screenshots/admin-document-catalogs-index.png)

#### 編集画面

![編集画面](screenshots/admin-document-catalogs-edit.png)

### companies 一覧

**用途:** 管理者がcompaniesの一覧画面で業務情報を確認する

#### 一覧画面

![一覧画面](screenshots/admin-companies-index.png)

#### 編集画面

![編集画面](screenshots/admin-companies-edit.png)

### users 一覧

**用途:** 管理者がusersの一覧画面で業務情報を確認する

#### 一覧画面

![一覧画面](screenshots/admin-users-index.png)

#### 編集画面

![編集画面](screenshots/admin-users-edit.png)

### project_memberships 一覧

**用途:** 管理者がproject_membershipsの一覧画面で業務情報を確認する

#### 一覧画面

![一覧画面](screenshots/admin-project-memberships-index.png)

#### 編集画面

![編集画面](screenshots/admin-project-memberships-edit.png)

### consent_terms 一覧

**用途:** 管理者がconsent_termsの一覧画面で業務情報を確認する

#### 一覧画面

![一覧画面](screenshots/admin-consent-terms-index.png)

#### 編集画面

![編集画面](screenshots/admin-consent-terms-edit.png)

### project_consent_settings 一覧

**用途:** 管理者がproject_consent_settingsの一覧画面で業務情報を確認する

#### 一覧画面

![一覧画面](screenshots/admin-project-consent-settings-index.png)

#### 編集画面

![編集画面](screenshots/admin-project-consent-settings-edit.png)

### Git連携設定一覧

**用途:** 管理者がGit連携ソースの設定状況と同期履歴を確認する

#### 一覧画面

**この画面での操作:**

- 連携設定の追加・編集・削除
- 手動同期の実行

![一覧画面](screenshots/admin-git-import-sources-index.png)

#### 編集画面

![編集画面](screenshots/admin-git-import-sources-edit.png)

### git_import_runs 一覧

**用途:** 管理者がgit_import_runsの一覧画面で業務情報を確認する

#### 一覧画面

![一覧画面](screenshots/admin-git-import-runs-index.png)

### 外部フォルダ同期設定一覧

**用途:** 管理者が外部フォルダ同期ソースの設定状況を確認する

#### 一覧画面

**この画面での操作:**

- Google Drive / SharePoint 同期設定の管理
- dry-run → レビュー → 適用のフロー
- OAuth接続・Webhook購読の管理

![一覧画面](screenshots/admin-external-folder-sync-sources-index.png)

#### 詳細画面

![詳細画面](screenshots/admin-external-folder-sync-sources-show.png)

#### 編集画面

![編集画面](screenshots/admin-external-folder-sync-sources-edit.png)

### microsoft_graph_connections 一覧

**用途:** 管理者がmicrosoft_graph_connectionsの一覧画面で業務情報を確認する

#### 一覧画面

![一覧画面](screenshots/admin-microsoft-graph-connections-index.png)

#### 編集画面

![編集画面](screenshots/admin-microsoft-graph-connections-edit.png)

### zip_imports 新規作成

**用途:** 管理者がzip_importsの新規作成画面で業務情報を確認する

#### 新規作成画面

![新規作成画面](screenshots/admin-zip-imports-new.png)

### file_upload_dry_runs 一覧

**用途:** 管理者がfile_upload_dry_runsの一覧画面で業務情報を確認する

#### 一覧画面

![一覧画面](screenshots/admin-file-upload-dry-runs-index.png)

#### 詳細画面

![詳細画面](screenshots/admin-file-upload-dry-runs-show.png)

### bulk_edit_dry_runs 新規作成

**用途:** 管理者がbulk_edit_dry_runsの新規作成画面で業務情報を確認する

#### 新規作成画面

![新規作成画面](screenshots/admin-bulk-edit-dry-runs-new.png)

### missing_document_files 詳細

**用途:** 管理者がmissing_document_filesの詳細画面で業務情報を確認する

#### 詳細画面

![詳細画面](screenshots/admin-missing-document-files-show.png)

## システム管理

### Webhook設定一覧

**用途:** 管理者がWebhook通知先の設定と送信状況を確認する

#### 一覧画面

**この画面での操作:**

- Webhookエンドポイントの追加・編集・削除
- イベント種別の設定

![一覧画面](screenshots/admin-webhook-endpoints-index.png)

#### 編集画面

![編集画面](screenshots/admin-webhook-endpoints-edit.png)

### webhook_deliveries 一覧

**用途:** 管理者がwebhook_deliveriesの一覧画面で業務情報を確認する

#### 一覧画面

![一覧画面](screenshots/admin-webhook-deliveries-index.png)

#### 詳細画面

![詳細画面](screenshots/admin-webhook-deliveries-show.png)

### アクセスログ

**用途:** 管理者がポータルへのアクセス履歴を監査する

#### 一覧画面

**この画面での操作:**

- ユーザー・案件・会社・日付によるフィルタ
- CSV出力

![一覧画面](screenshots/admin-access-logs-index.png)

### access_requests 一覧

**用途:** 管理者がaccess_requestsの一覧画面で業務情報を確認する

#### 一覧画面

![一覧画面](screenshots/admin-access-requests-index.png)

#### 詳細画面

![詳細画面](screenshots/admin-access-requests-show.png)

### document_usage_reports 一覧

**用途:** 管理者がdocument_usage_reportsの一覧画面で業務情報を確認する

#### 一覧画面

![一覧画面](screenshots/admin-document-usage-reports-index.png)

### read_confirmations 一覧

**用途:** 管理者がread_confirmationsの一覧画面で業務情報を確認する

#### 一覧画面

![一覧画面](screenshots/admin-read-confirmations-index.png)

### recurring_job_schedules 一覧

**用途:** 管理者がrecurring_job_schedulesの一覧画面で業務情報を確認する

#### 一覧画面

![一覧画面](screenshots/admin-recurring-job-schedules-index.png)

#### 詳細画面

![詳細画面](screenshots/admin-recurring-job-schedules-show.png)

### generated_file_events 一覧

**用途:** 管理者がgenerated_file_eventsの一覧画面で業務情報を確認する

#### 一覧画面

![一覧画面](screenshots/admin-generated-file-events-index.png)

#### 詳細画面

![詳細画面](screenshots/admin-generated-file-events-show.png)

### generated_file_runs 一覧

**用途:** 管理者がgenerated_file_runsの一覧画面で業務情報を確認する

#### 一覧画面

![一覧画面](screenshots/admin-generated-file-runs-index.png)

#### 詳細画面

![詳細画面](screenshots/admin-generated-file-runs-show.png)

