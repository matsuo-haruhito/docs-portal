# Maintenance-Mode 境界一覧

inclusion: manual

---

## 統合元ファイル一覧

| ファイル | 最終 commit |
|---------|-------------|
| docs/会社ユーザー案件所属maintenance-mode境界.md | 6a24341f2e737c19d445a51b2ef194118c9b9ca0 |
| docs/文書マスタmaintenance-mode境界.md | af5491a9fdd2ae84b3a9648b5ccd20c8a86e8e91 |
| docs/文書権限maintenance-mode境界.md | 4926fd8b0cd7a4ce95176909b28b1952bd4aafbb |
| docs/文書セットmaintenance-mode境界.md | 05dacbbab6f39518047846f3fef9a2b22880b97c |
| docs/文書一括編集maintenance-mode境界.md | 831caa27247140fa382733d0dfd8b4b3cce88307 |
| docs/文書カタログmaintenance-mode境界.md | 19a5192473b84a2413a11fb55a6c37cbdf5c3ea6 |
| docs/文書ショートカットmaintenance-mode境界.md | 557334eb269be2523fd3bf4e62c202f60e45c423 |
| docs/文書コメントQ&Amaintenance-mode境界.md | 1af735bb45a5fe558d74c49067c151933bd9e481 |
| docs/文書版rollbackmaintenance-mode境界.md | 6bf08c574894d590f31f4bcfbc8c83a0ddd59b8f |
| docs/既読確認maintenance-mode境界.md | 2169fe408eeb0e15ae5f86014e3b281a05d48fd6 |
| docs/確認依頼maintenance-mode境界.md | 842b60e5bc2a8f1bcfd46598299b61414bb9c988 |
| docs/外部送付履歴maintenance-mode境界.md | 6d6c0a10efc310c1f6826e6e9715b5699e316d0f |
| docs/アクセス申請maintenance-mode境界.md | 87acf11cc22d6f45899129aa22e7b13273c11e20 |
| docs/同意管理maintenance-mode境界.md | 2a76648a571a3fedee3d920aea8cf19430e57dd2 |
| docs/Git手動同期maintenance-mode境界.md | 63e1883b14a2b198009a4adf4d3462f1e3dd50ff |
| docs/手動アップロードmaintenance-mode境界.md | eb7cddd5d126585e9f8932c5c4277aea7efa2473 |
| docs/internal upload API maintenance-mode境界.md | 100bf89f9de0900ed973b7a218992914f7b5292f |
| docs/Git連携source設定maintenance-mode境界.md | c485ac633d921385b25d52ebdc403042b6a3b887 |
| docs/外部フォルダ同期source設定maintenance-mode境界.md | 59cf6c1ed612904673b03c0a5ace00803fd1407d |
| docs/外部フォルダ同期OAuth接続maintenance-mode境界.md | 097ccd840ab46f4bd5a4724e137e4c3d9837a7d3 |
| docs/外部フォルダ同期webhook-maintenance-mode境界.md | 3fd72f23a89fa8c3fae22c344e47e162963ba958 |
| docs/Webhook設定maintenance-mode境界.md | 723cd26761890ed7e5aa31399c298f30e3921f4c |
| docs/Microsoft Graph接続maintenance-mode境界.md | b5e1b6dea3cd49df7691bbbed1169c0c61ef2c0c |
| docs/API仕様codeblock-dry-run maintenance境界.md | 5b715d2863c53d434e6f25b87d59fec4fc340e93 |
| docs/Storage使用量CSV-read-only-handoff境界メモ.md | 18d677994bea5d1c4c817c0b768de89e6f9dc1a8 |

---

READ_ONLY_MAINTENANCE 中に止める変更操作と read-only に残す確認導線の一覧。

## 基本マスタ

| 機能 | 止める操作 | read-only に残す操作 |
|------|-----------|-------------------|
| 会社・ユーザー・案件所属 | companies / users / project_memberships の create / update / destroy | 一覧、検索、filter、pagination、selected endpoint による現在値確認、company_master_admin の自社 scope 確認 |

## 文書・権限

| 機能 | 止める操作 | read-only に残す操作 |
|------|-----------|-------------------|
| 文書マスタ編集 | Document の create / update / archive / restore / destroy | 文書マスタ一覧、検索 / filter / pagination、編集画面の現在値確認、案件 remote search、lifecycle handoff JSON、公開側文書への戻り導線、最新版 / HTML preview 状態確認 |
| 文書権限付与 | DocumentPermission の create / update / destroy（会社・ユーザー単位の権限） | 文書別権限概要、権限一覧、案件 / 文書名 / 権限 / 付与先 filter、remote search と selected restore、CSV 出力 |
| 文書セット編集 | DocumentSet / DocumentSetItem の create / update / destroy、固定版指定の変更 | 管理側一覧、filter、CSV 出力、CSV 条件 metadata JSON、remote search、edit 画面の現在値確認、公開側文書セット一覧 / 詳細 |
| 文書一括編集 | 新規 dry-run 作成、既存 dry-run の確認実行、Document / DocumentVersion / tag / archive state の bulk 更新 | dry-run 対象選択画面、handoff JSON、既存 dry-run detail、preview summary / warning / error / diff 確認 |
| 文書カタログ | DocumentCatalog / DocumentCatalogItem の create / update / destroy | 公開側 catalog 一覧 / 詳細、管理側 catalog 一覧、edit 画面の現在値確認、project / document remote search |
| 文書ショートカット | DocumentBookmark の create（お気に入り / 後で読む）、move_to_favorite、destroy | ショートカット一覧（お気に入り / 後で読む）、案件 filter / 検索語 filter、最近見た文書表示、pagination、文書詳細リンク |
| 文書コメント・Q&A | DocumentReviewComment の create（Q&A / 返信 / 確認事項）、update（回答済み / クローズ / 解決） | 文書詳細 / 版詳細の workspace 表示、検索、投稿者 filter、未解決 handoff summary |
| 版 rollback | DocumentVersionRollback の実行（version status / latest_version_id / archive 状態の変更） | 版詳細、差分、品質チェック、添付・元ファイル確認、直前版・既存版確認 |
| 既読確認 | ReadConfirmation の create（既読にしました）/ destroy（既読を解除） | 文書閲覧、管理側の文書利用状況集計、既読確認内訳（確認日時・確認者・会社・文書 slug） |
| 確認依頼 | DocumentApprovalRequest の create / update（approve）/ cancel | 確認依頼の全体一覧、文書配下一覧、detail、status / requester / approver filter、return_to 戻り |
| 外部送付履歴 | DocumentDeliveryLog の create（下書き作成）/ update（送付済み / 送付失敗） | 送付履歴一覧、検索 / filter / pagination、CSV export、detail の mailto URL 確認、failure_alert_handoff |
| アクセス申請 | AccessRequest の送信、取消、承認、却下 | 利用者側申請一覧（検索 / status / 権限 / 種別 filter / pagination）、admin 側一覧 / detail、pending handoff JSON |
| 同意管理 | UserConsent の create、ConsentTerm の create / update / destroy、ProjectConsentSetting の create / update / destroy | 利用者側の同意履歴 / active 文面確認、未同意文面確認、admin 側 consent_terms / project_consent_settings 一覧 / filter / edit 表示 / remote search |

## import・sync

| 機能 | 止める操作 | read-only に残す操作 |
|------|-----------|-------------------|
| Git手動同期 | GitImportSourceSyncer の起動（GitImportRun 作成、同期 job、外部 fetch、import 実行） | Git連携設定一覧 / edit、Git同期履歴一覧 |
| Git連携 source 設定 | GitImportSource の create / update / destroy（repository / branch / source path / 認証方式 / credential / enabled 状態） | Git連携設定一覧、repository / branch / source path / enabled 検索 / filter、project / repository remote picker、Git同期履歴一覧 |
| 手動アップロード | DocumentUpload の create（candidate / Document / Version / File 作成 / preview job enqueue）、upload review の approve / reject | 案件の文書一覧、文書詳細、版詳細、既存 upload review 画面、既存版 / 添付 / 差分 / preview 確認 |
| internal upload API | artifact_imports / zip_uploads / file_uploads の apply request（DocumentImporter / PublishJob / ImportDryRun confirmed 化） | dry-run 作成（validate_only=true）、既存 dry-run 一覧 / detail 確認 |
| sales-mgt master sync API | 未確定の idempotency request による Company / Project / Document の upsert / archive、外部mapping・receiptの新規確定 | 同一key・同一digestで確定済みreceiptの応答、既存mappingと同期履歴の確認 |
| 文書一括編集 dry-run | （文書一括編集セクションに含む） | （文書一括編集セクションに含む） |

## 外部連携

| 機能 | 止める操作 | read-only に残す操作 |
|------|-----------|-------------------|
| 外部フォルダ同期 source 設定 | ExternalFolderSyncSource の create / update / destroy（provider / folder URL / auth type / metadata / enabled 状態） | source 一覧 / 詳細、検索 / provider filter / warning・error filter、project search、直近 run / 同期履歴 / 同期 item / 受信 event 確認 |
| 外部フォルダ同期 OAuth 接続 | OAuth authorization redirect / state 発行、callback による token exchange / 保存、OAuth token 削除 | 外部フォルダ同期設定一覧 / 詳細、同期履歴 / 同期アイテム、変更通知の購読状態 / 受信イベント表示、SharePoint metadata 確認 |
| 外部フォルダ同期 webhook | webhook 受信後の ExternalFolderSyncWebhookEventJob enqueue、source単位run予約・実行権交代、reconciliation による stale run / event 回収、enqueue 済み ExternalFolderSyncJob の同期開始 | Google Drive webhook への 200 OK 応答、SharePoint validationToken / notification 応答、ExternalFolderSyncWebhookEvent 記録、既存run・実行権・検証境界の確認 |
| Docusaurus preview build | enqueue済み `DocusaurusPreviewBuildJob` のclaim・renderer実行・artifact作成/置換・preview状態/試行回数/時刻更新、reconciliationによる再enqueue・artifact修復 | queue済みintent、preview状態、試行回数、claim情報、既存artifact、版詳細・preview状態の確認 |
| Webhook 設定・再送 | WebhookEndpoint の create / update / destroy（URL / secret / active / event types）、手動再送、自動再送のclaim・stale claim回収・HTTP POST | Webhook endpoint 一覧、最近の送信履歴、送信履歴詳細、自動再送状態・retry count・claim取得日時、failure alert handoff |
| Microsoft Graph 接続 | MicrosoftGraphConnection の create / update / destroy（Tenant ID / Client ID / secret / Site ID / Drive ID / preview folder / enabled） | 接続一覧、preview 利用状態 / 重複有効接続 / 検索 / filter、案件 remote search、共有 URL 候補取得（保存なし） |
| API 仕様 codeblock dry-run | retry_build / stale build enqueue（Docusaurus build 起動） | codeblock_dry_run（request sample の形式確認 — dry_run: true / destructive: false） |
| Storage 使用量 CSV | — | document_files / docs_sites / imports の CSV download（bounded list としての read-only handoff） |

## viewer操作

| 機能 | 止める操作 | read-only に残す操作 |
|------|-----------|-------------------|
| (viewer側は確認導線のみで操作なし) | — | — |
