# 運用 metadata 情報露出点検チェックリスト

この checklist は、admin / integration 運用画面で扱う sensitive metadata の表示境界を点検する入口です。

社外ユーザーが権限外文書を見られないことの点検は [社外ユーザー向け情報露出点検チェックリスト](./社外ユーザー向け情報露出点検チェックリスト.md) を正本にします。この文書では、管理者や運用者に見える raw path、payload、外部サービス識別子、webhook header などが、調査に必要な範囲を超えて表示されていないかを確認します。

## 点検対象

次のような値は、外部ユーザー向けの閲覧権限とは別に、admin / integration metadata として点検する。

- client / local folder 由来の `source_path`
- registered file の `storage_key` と、そこから組み立てる expected path preview
- Webhook の request body / response body / error message
- 外部フォルダ同期の webhook headers / payload
- Microsoft Graph の `drive_id` / `folder_item_id` / `folder_path` / `site_id`
- Google Drive の channel id / resource id / message number
- 生成ファイル実行履歴 index の q 検索対象になる metadata / path / error 断片
- 生成ファイル実行履歴 detail の metadata / error preview
- Git 連携設定 / Git同期履歴の repository、branch、source path、commit、summary_json、error preview、credential ref
- import / dry-run / sync の raw JSON に含まれる path、外部 ID、token-like value

## 現在の入口

代表 request spec をまとめて再実行したい場合は、次の smoke command を使います。

```bash
bundle exec ruby bin/operational_metadata_exposure_smoke
```

この command は、既存の current behavior guard を束ねる read-only 入口です。`bin/external_user_exposure_smoke` は社外ユーザー向けの権限外情報露出を確認する入口であり、この command は admin / integration metadata の表示境界を確認する入口として分けて扱います。追加引数はそのまま `rspec` へ渡せます。

PR / release / 運用引き継ぎ用に短い evidence だけ残したい場合は、Markdown digest を使います。

```bash
bundle exec ruby bin/operational_metadata_exposure_smoke --format markdown
bundle exec ruby bin/operational_metadata_exposure_smoke --format=markdown
```

Markdown digest は smoke 名、実行時刻、RSpec 結果、追加で渡した RSpec args、代表 spec、surface、確認目的、次に見る runbook だけを出します。raw path、raw payload、token-like value、PII-like value、Webhook / Graph の詳細本文、外部 ID の生値、provider payload は digest に貼らない。完全な失敗内容は対象 spec / 画面 / runbook へ戻って確認します。

first slice で束ねる spec subset は次です。

- `spec/requests/admin_file_upload_dry_runs_spec.rb`
- `spec/requests/admin_missing_document_files_spec.rb`
- `spec/requests/admin_webhook_deliveries_spec.rb`
- `spec/requests/admin_external_folder_sync_sources_spec.rb`
- `spec/requests/admin_external_folder_sync_webhook_event_exposure_spec.rb`
- `spec/requests/admin_microsoft_graph_connections_spec.rb`
- `spec/requests/admin_generated_file_run_operational_metadata_exposure_spec.rb`
- `spec/requests/admin_git_import_operational_metadata_exposure_spec.rb`

`spec/docs/exposure_smoke_checklist_drift_spec.rb` は、この subset と `bin/operational_metadata_exposure_smoke` の `SPEC_FILES` / Markdown digest rows が一致していることを source-level guard として確認する。代表 spec を追加・削除する場合は、smoke script とこの節を同じ PR で更新し、社外ユーザーの閲覧権限境界を確認する spec は [社外ユーザー向け情報露出点検チェックリスト](./社外ユーザー向け情報露出点検チェックリスト.md) 側へ分ける。

この subset は、manual upload dry-run、欠落文書ファイル expected path、Webhook delivery preview / search、外部フォルダ同期 metadata、Microsoft Graph provider metadata、生成ファイル実行履歴 index の q 検索と detail の metadata / error preview、Git 連携設定 / Git同期履歴の credential / summary / error preview の代表 guard に限定します。Webhook / Graph / import / dry-run / generated file run の runtime 表示仕様、secret / token / PII 判定、保存方針、CI 必須化はこの smoke command では決めません。

| 対象 | 最初に見る docs / 画面 | current behavior と点検観点 | 関連 issue |
| --- | --- | --- | --- |
| manual upload dry-run の `source_path` | [internal upload API dry-run・apply運用runbook](./internal%20upload%20API%20dry-run・apply運用runbook.md)、`admin/file_upload_dry_runs/:public_id` | `source_name` / `relative_path` / `content_hash` は照合に使う。raw `source_path` の表示範囲は security-adjacent な UI 判断として扱い、保存値や apply 条件の変更と混ぜない。 | `#1613` |
| 生成ファイル実行履歴 index の q 検索と detail の metadata / error preview | [生成ファイル再試行と定期ジョブ管理 runbook](./生成ファイル再試行と定期ジョブ管理runbook.md)、[生成ファイル実行履歴 preview 境界メモ](./生成ファイル実行履歴preview境界メモ.md)、`admin/generated_file_runs`、`admin/generated_file_runs/:public_id` | index の q 検索は実行ID、入力パス、変更ファイル、生成パス、短いエラー断片、metadata に残る event public ID などの短い診断用断片で候補を絞る入口として読む。検索対象に metadata text が含まれていても、一覧 HTML で raw metadata / raw payload / token-like value / private path を読む導線ではない。detail の `入力パス` / `変更ファイル` / `生成パス` はジョブ診断用の配列 preview として読み、`メタデータ` / `エラー` は `generated_file_run_metadata_preview` / `generated_file_run_diagnostic_preview` を通して token-like value、authorization 断片、private-looking path が raw 表示されていないかを点検する。 | `#3673` / `#3891` / `#3892` |
| Git連携設定 / Git同期履歴の credential / summary / error preview | [Git連携設定と同期失敗確認 runbook](./Git連携設定と同期失敗確認runbook.md)、`admin/git_import_sources`、`admin/git_import_runs` | `Git連携` は repository、branch、取込元 path、installation ID、最終同期 commit を調査識別子として表示する。保存済み `credential_secret` や `credential_ref` は一覧 HTML に出さない。`Git同期履歴` は `summary_json` と `error_message` をマスク済み preview として表示し、token-like value、authorization 断片、secret、private-looking path を raw 表示しない。 | `#3830` |
| 欠落文書ファイル詳細の `Expected path` | [管理ダッシュボード・モデルブラウザ運用runbook](./管理ダッシュボード・モデルブラウザ運用runbook.md)、[ファイル配信・storage運用方針](./ファイル配信・storage運用方針.md)、`admin/missing_document_files` | current `main` は `Storage key` を識別子として残しつつ、`Expected path` を `storage/document_files/...` 形式の safe preview で表示する。raw absolute path や `Rails.root` を通常 UI で読む前提にせず、調査には storage key、文書・版リンク、storage / database 側の確認を組み合わせる。 | `#2227` / PR `#2238` |
| Webhook 送信履歴 detail の request body | [Webhook設定・送信失敗確認runbook](./Webhook設定・送信失敗確認runbook.md)、`admin/webhook_deliveries/:public_id` | current `main` は `WebhookRequestBodyPreview` で request body をマスク済み preview として表示する。secret、token、authorization、個人情報らしい key の値、長大本文が raw 表示されていないかを点検する。 | `#1434` / PR `#1447` |
| Webhook 一覧トップ / 送信履歴検索の `エラー` preview | [Webhook設定・送信失敗確認runbook](./Webhook設定・送信失敗確認runbook.md)、`admin/webhook_endpoints`、`admin/webhook_deliveries` | current `main` は `WebhookDeliveryDiagnosticPreview` で error message を一覧・検索用の短い preview として表示する。token-like value、authorization 断片、private-looking path、長い message が一覧で raw 表示されていないかを点検し、raw error 全文や詳細調査は detail 側の response body / target URL と分けて読む。 | `#2100` / `#2167` / `#2170` / PR `#2287` / PR `#2430` |
| Webhook 送信履歴 detail の response body / error message / target URL | [Webhook設定・送信失敗確認runbook](./Webhook設定・送信失敗確認runbook.md)、`admin/webhook_deliveries/:public_id` | current `main` は `WebhookDeliveryTargetUrlDisplay` で送信先 URL の scheme / host / path（必要な port を含む）を残し、query は `?...` に畳む。error message / response body は `WebhookDeliveryDiagnosticPreview` で token-like value、authorization 断片、private path を mask し、長大本文は省略する。request body preview とは別 class / 別観点で読み、代表 request spec / smoke 固定は `#2949` の範囲として分ける。 | `#1434` / `#1895` / `#2949` |
| Google Drive 変更通知の headers / payload | [外部フォルダ同期dry-run・apply運用runbook](./外部フォルダ同期dry-run・apply運用runbook.md)、`外部フォルダ同期設定詳細` | 受信イベントでは channel id、resource id、message number、event key、関連 run を確認する。検証 token や webhook header の raw 値を運用確認用 metadata として扱わない。 | `#1752` / `#1751` |
| SharePoint / OneDrive の Graph metadata | [外部フォルダ同期dry-run・apply運用runbook](./外部フォルダ同期dry-run・apply運用runbook.md)、[Microsoft Graph接続管理runbook](./Microsoft%20Graph接続管理runbook.md) | `drive_id` / `folder_item_id` / `folder_path` / `site_id` は共有 URL から保存できた metadata の確認用。同期本体、Graph subscription 作成、変更通知運用が current support になったとは読まない。 | `#1030` 以降 |

## 点検手順

1. 対象画面が外部ユーザー向け導線か、admin / integration 運用導線かを先に分ける。
2. 画面で raw JSON、raw path、raw payload、外部 ID、header を表示している箇所を探す。
3. 調査に必要な非秘密識別子と、表示しないほうがよい secret / token / private path / PII を分ける。
4. current behavior が mask / truncation / preview を持つ場合は、raw value が HTML response に残らないことを spec や review で確認する。
5. current behavior が raw 表示の場合は、docs だけで安全化したことにせず、表示変更や保存方針が必要かを別 issue に戻す。
6. 画面表示だけでなく、JSON / Markdown / ZIP / Webhook payload など出力物に同じ raw value が入っていないかを必要に応じて確認する。

## 合格基準

- `bin/operational_metadata_exposure_smoke` で admin / integration metadata の代表 request spec をまとめて再実行できる
- admin / integration metadata の点検入口が、社外ユーザー向けの権限外情報露出 checklist と混線していない
- raw path、raw payload、token-like value、PII-like value を current support として表示しているか、mask / truncation / safe preview 済みなのかが分かる
- PR / release / 運用引き継ぎでは `--format markdown` の短い digest を使い、raw values や詳細 payload を貼らずに代表 spec の結果と次に見る runbook だけを残せる
- `source_path`、欠落文書ファイルの `Expected path`、Webhook request body、Webhook error / response / target URL preview、Graph provider metadata、webhook headers、生成ファイル実行履歴 index の q 検索と detail の metadata / error preview、Git 連携設定 / Git同期履歴の credential / summary / error preview の代表観点をそれぞれ別に確認できる
- 実装済み current behavior と、issue 化済みの改善候補を同じ文として断定していない
- runtime code、DB schema、認可、security policy の最終判断をこの checklist で新規に決めていない

## 停止条件

次の場合は docs だけで完了させず、人間判断または runtime issue に戻す。

- raw value を表示してよいか、業務上の許容範囲が判断できない
- 保存済み metadata の削除、暗号化、retention、audit policy が必要になる
- mask すべき key や PII 判定を新しく決める必要がある
- 外部 API、Webhook 署名、Graph subscription、同期本体の仕様変更が必要になる
- 社外ユーザー向け権限境界と admin-only 運用 metadata のどちらを正本にするか判断が割れる

## 関連 docs

- [社外ユーザー向け情報露出点検チェックリスト](./社外ユーザー向け情報露出点検チェックリスト.md)
- [Webhook設定・送信失敗確認runbook](./Webhook設定・送信失敗確認runbook.md)
- [外部フォルダ同期dry-run・apply運用runbook](./外部フォルダ同期dry-run・apply運用runbook.md)
- [Microsoft Graph接続管理runbook](./Microsoft%20Graph接続管理runbook.md)
- [Git連携設定と同期失敗確認 runbook](./Git連携設定と同期失敗確認runbook.md)
- [生成ファイル実行履歴 preview 境界メモ](./生成ファイル実行履歴preview境界メモ.md)
- [internal upload API dry-run・apply運用runbook](./internal%20upload%20API%20dry-run・apply運用runbook.md)
- [管理ダッシュボード・モデルブラウザ運用runbook](./管理ダッシュボード・モデルブラウザ運用runbook.md)
- [ファイル配信・storage運用方針](./ファイル配信・storage運用方針.md)
