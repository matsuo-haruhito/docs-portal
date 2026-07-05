# 外部フォルダ同期 OAuth 接続 maintenance mode 境界

このメモは Issue #4592 の first slice として、Google Drive 外部フォルダ同期の OAuth 接続 lifecycle を `READ_ONLY_MAINTENANCE` 中に止める境界を固定します。

## current support

`READ_ONLY_MAINTENANCE` が有効な間は、次の OAuth 接続 lifecycle 操作を開始しません。

- `ExternalFolderSyncOauthConnectionsController#new`
  - Google OAuth authorization への redirect
  - OAuth state の新規発行
- `ExternalFolderSyncOauthConnectionsController#callback`
  - authorization code の token exchange
  - refresh token / access token / expires_at / scope / token_type の保存
- `ExternalFolderSyncOauthConnectionsController#destroy`
  - 保存済み OAuth token の削除

停止時は 500 にせず、管理者が理由を読める alert 付きで対象の外部フォルダ同期設定詳細へ戻します。

## read-only として残す導線

maintenance mode 中も、次の確認導線は止めません。

- 外部フォルダ同期設定一覧
- 外部フォルダ同期設定詳細
- 同期履歴
- 同期アイテム
- 変更通知の購読状態と受信イベントの表示
- SharePoint / OneDrive metadata-only source の保存済み metadata 確認

これらは保存済み設定と履歴を読むための導線であり、OAuth token の新規保存や削除とは分けて扱います。

## maintenance mode OFF

`READ_ONLY_MAINTENANCE` が無効なときは、既存どおり次の操作を許可します。

- Google Drive OAuth 接続開始
- OAuth callback による token 保存
- OAuth 接続解除

Google OAuth の client id / secret 未設定、provider / auth type 不一致、state mismatch などの既存エラー境界は維持します。

## 非目標

この first slice では次を扱いません。

- Google Drive `dry_run` / `apply` / `force_apply` / `enqueue`
- Google Drive 変更通知の購読開始 / 停止
- 外部フォルダ同期 source CRUD
- SharePoint / OneDrive metadata recheck
- Google / Microsoft Graph credential policy や token rotation policy の最終判断
- provider API contract、DB schema、認可条件、sync runner の変更
- production infra 側 maintenance page

## 確認観点

- maintenance mode ON で OAuth 接続開始が Google authorization redirect へ進まない
- maintenance mode ON で OAuth callback が token exchange や auth_config 更新へ進まない
- maintenance mode ON で OAuth 接続解除が保存済み token を削除しない
- maintenance mode ON でも source 詳細は read-only に確認できる
- maintenance mode OFF の既存解除 flow は壊れていない

## 関連

- Issue #4592
- `app/controllers/admin/external_folder_sync_oauth_connections_controller.rb`
- `docs/外部フォルダ同期dry-run・apply運用runbook.md`
- `docs/preview接続と外部フォルダ同期の設定責務.md`
- `docs/本番運用・インフラ前提.md`
