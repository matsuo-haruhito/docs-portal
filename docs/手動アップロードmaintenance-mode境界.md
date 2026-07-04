# 手動アップロード maintenance mode 境界

このメモは Issue #4496 の first slice として、手動アップロード開始と upload review の `OK` / `NG` を `READ_ONLY_MAINTENANCE` 中に止める境界を固定します。

## current support

`READ_ONLY_MAINTENANCE` が有効な間は、次の変更系操作を開始しません。

- `DocumentUploadsController#create`
  - manual upload candidate 作成
  - `Document` / `DocumentVersion` / `DocumentFile` 作成
  - Markdown preview job enqueue
- `DocumentVersionUploadReviewsController#create`
  - `decision=approve` による draft upload version の publish
  - `Document#latest_version` の切り替え
  - `decision=reject` による upload candidate archive

停止時は 500 にせず、利用者が理由を読める alert 付きで既存の確認導線へ戻します。

- upload 開始は対象案件の文書一覧へ戻す
- upload review の `OK` / `NG` は対象版の版詳細へ戻す

## read-only として残す導線

maintenance mode 中も、次の確認導線は止めません。

- 案件の文書一覧
- 文書詳細
- 版詳細
- 既存の upload review 画面
- 既存版、添付、差分、preview 状態の確認

## 非目標

この first slice では次を扱いません。

- ZIP import / Git import / external folder sync / internal upload API の停止境界
- 文書版 rollback の停止境界
- storage policy や文書版 model の再設計
- 承認 workflow、通知、SLA の追加
- production infra 側 maintenance page
- browser evidence や UI redesign

## 関連

- Issue #4496
- `docs/手動アップロード差異確認runbook.md`
- `docs/本番運用・インフラ前提.md`
