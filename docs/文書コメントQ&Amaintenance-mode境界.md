# 文書コメント / Q&A maintenance mode 境界

このメモは `READ_ONLY_MAINTENANCE` 中の文書コメント / Q&A workspace の変更停止境界を整理します。

## current support

- `DocumentReviewCommentsController#create` は maintenance mode 中に新しい Q&A、返信、内部向け確認事項を作成しません。
- `DocumentReviewCommentsController#update` は maintenance mode 中に Q&A の回答済み / クローズ、確認事項の解決を更新しません。
- 停止時は 500 にせず、現在の文書詳細または版詳細の workspace 文脈へ戻して、投稿・状態更新が停止中であることを alert で表示します。
- 文書詳細、版詳細、workspace 表示、検索、投稿者 filter、未解決 handoff summary は read-only に確認できます。
- maintenance mode OFF では既存の投稿、返信、状態更新、戻り先文脈を維持します。

## 非目標

- 通知、SLA、担当割当、自動エスカレーションの追加
- 正式レビュー承認 workflow の導入
- Q&A / 確認事項の status model 再設計
- visibility policy、DocumentVersion、DocumentFile、権限 model の変更
- workspace UI redesign
- production infra 側 maintenance page

## 確認観点

- maintenance mode ON で `DocumentReviewComment` が作成されないこと
- maintenance mode ON で既存 comment の `status` / `resolved_by` / `resolved_at` が変わらないこと
- maintenance mode ON でも既存 Q&A / 確認事項を閲覧できること
- maintenance mode OFF の既存 create / update flow が壊れていないこと
