# 文書版 rollback maintenance-mode 境界

この文書は issue `#4542` に対応し、`READ_ONLY_MAINTENANCE` 中の文書版 rollback の扱いを整理します。

## current support

`READ_ONLY_MAINTENANCE` が有効な間、反映済みの手動アップロード版に対する `このアップロードを取り消す` は停止します。

- `DocumentVersionRollbacksController#create` は `DocumentVersionRollback` を呼び出しません。
- 対象の `DocumentVersion` status、`Document#latest_version_id`、文書の archive 状態は変更しません。
- 停止時は版詳細へ戻し、internal user がメンテナンス中であることを読める alert を表示します。

## read-only に残す導線

maintenance mode 中でも、次は閲覧・確認の導線として残します。

- 版詳細
- 差分
- 品質チェック
- 添付・元ファイル確認
- 直前版や既存版の確認

## 非目標

この slice では次を変更しません。

- `DocumentVersion` schema
- rollback policy
- retention policy
- 正式承認 workflow
- 監査 model
- 認可条件や internal user 判定
- 手動アップロード review flow 全体
- 通知、理由入力 UI、SLA

## 確認観点

- maintenance mode ON では rollback request が状態を変えないこと
- maintenance mode OFF では既存 rollback 成功時の戻り先と flash が維持されること
- 外部ユーザーや不正な rollback 対象に対する既存の forbidden / BadRequest 境界を広げていないこと
