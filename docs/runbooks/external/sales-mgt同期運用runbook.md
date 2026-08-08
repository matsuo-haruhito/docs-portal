# sales-mgt同期運用runbook

## 目的

`sales-mgt` を正本とする会社・案件・文書メタデータが `docs-portal` へ届かない、重複する、または古い状態へ戻ったように見える場合の確認順を定めます。同期方式とAPI契約の正本は [Webhook・外部API連携方針](../../specs/Webhook・外部API連携方針.md) と [API仕様](../../../docs-src/api-specification.md) です。

## 正常状態

- `sales-mgt` の業務更新と同じ transaction で outbox event が作成される
- event は `pending -> processing -> delivered` と進む
- `docs-portal` は `(source_system, resource_type, external_id)` で同じ対象を更新する
- timeout 後に同じ event が再送されても、同じ `Idempotency-Key` と request digest なら同じ結果になる
- `source_updated_at` が古い event は stale no-op として delivered になり、現在値を巻き戻さない

## 最初の確認順

1. `sales-mgt` の同期履歴一覧で resource、external ID、状態、試行回数、次回試行を確認する
2. `pending` のままなら worker と dispatch reconciliation の直近runを確認する
3. `processing` のままなら lock時刻を確認し、stale processing回収の直近runを確認する
4. `failed` は最終HTTP status / errorから一時障害かを判断し、`available_at`後の自動再試行を待つ
5. `dead` は自動再送されない。validation、認証、idempotency conflict、最大試行到達の原因を直してから表示される手動再試行を使う
6. `delivered` なのに対象が見えない場合は response の portal public ID / URL と `docs-portal` の外部mappingを照合する

## 状態の読み方

| 状態 | 意味 | 操作 |
| --- | --- | --- |
| `pending` | 配送待ち | 通常は自動処理。長時間残る場合はworker / reconciliationを確認 |
| `processing` | claim済み | 実行中。短時間で手動再試行しない |
| `failed` | 再試行可能 | 次回試行を確認。必要なら原因解消後に許可された再試行 |
| `dead` | 自動再試行の終端 | 原因解消後だけ手動再試行 |
| `delivered` | 受信側で確定 | portal URLとmappingを確認 |

## HTTP別の切り分け

- responseなし / timeout / `408` / `429` / `5xx`: 初回失敗後に最大3回（1分・5分・30分）のbackoffで再試行
- `422`かつ `error_code=missing_dependency` / `retryable=true`: 親会社・親案件のmapping到着待ち。docs-portalはこの応答をreceiptへ確定せず、同じevent IDを再送できる
- その他の `400` / `422`: payload mappingまたは必須属性を修正。会社・案件の `active` はJSON literalの `true` / `false` だけを送り、文字列、数値、`null`は送らない。決定的validation errorはreceiptへ確定され、自動再送しない
- `401` / `403`: machine token、送信先URL、maintenance設定を確認。secretを画面やlogへ貼らない
- `409`: 同じidempotency keyで異なるbodyを送っている。eventを再利用せず、producerのpayload不変条件を修正する
- `503`かつ `error_code=read_only_maintenance`: 試行回数を消費せず間隔を空け、maintenance解除後に同じeventを再試行する

## reconciliation

- dispatch reconciliationはqueue投入欠落、期限到来failed、stale processingをbounded batchで回収する
- full reconciliationは現在の会社・案件・文書snapshotを再発行する
- 同じsnapshotはdeduplication keyでno-opになるが、一時HTTPエラーまたは再試行可能422で `dead` になった既存eventだけは pendingへ戻す。validation / 認証 / digest conflictの `dead` は自動復活させない
- maintenance応答は試行回数を消費しないため、長時間maintenanceでも最大試行回数だけを理由に `dead` へ移行しない

## docs-portal側の受信確認

管理画面の `モデルブラウザ` にある `外部マスタ同期マッピング` と `マスタ同期受領台帳` はread-onlyの運用確認面です。external IDからportal側対象を照合し、response status、idempotency key、完了時刻を確認します。request / response本文やtokenは一覧へ表示せず、payload修正やreceipt削除をこの画面から行いません。

## 文書ファイル

master syncは文書metadataとportal URLを対象とし、PDF / Office / Markdown本体をJSONへbase64で含めません。ファイル実体が必要な場合は、既存の `file_uploads` でdry-runを作り、review後にapplyします。metadata deliveredだけでファイル取込済みとは判断しません。

## maintenance

`docs-portal` の `READ_ONLY_MAINTENANCE` 中は、新規upsert / archiveを停止します。確定済みの同一idempotency requestは保存済みresponseを返せます。`sales-mgt` 側では履歴閲覧を残し、手動再試行を止めます。
