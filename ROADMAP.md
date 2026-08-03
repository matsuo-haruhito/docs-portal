# ROADMAP

## 現在地サマリ

- tree_view: 文書ツリー sidebar / current cue / server-side 展開状態保存 / 文書詳細本文側 state cue（適用済み画面: 2）
- rails_table_preferences: 一覧画面の列設定・ソート・フィルタ（適用済み画面: 9）
- rails_fields_kit: remote search / combobox / picker（適用済み画面: 9）
- Vite + Stimulus: gem JS entrypoint 読み込み基盤確立、Turbo > Stimulus > 素 JS の方針定着
- DocusaurusSiteRenderer: table rewrite による DOM 境界 metadata 付与（current support）

## 次のアクション

- rtp 新規一覧展開: 既存9画面の column metadata / filter / preset 確認完了後、未展開候補を issue 上で固定して着手
- rfk 横展開: 未対応画面の具体的な画面名・field 名を特定し issue を起票してから着手（代表画面は current support 済み）
- tree + table state 連携: 詳細一覧の列幅・表示状態保存を proposal として切り出し、pinned ref bump とは分離して検討
- ResourceTableRenderState viewer 反映: #4071 で docs-only 境界固定後、guard 方式を別 issue で決定
- Stimulus 化継続: 既存素 JS を触るタイミングで controller 化。Markdown table の full RTP 統合は #475 に残す

## 候補（未確定）

- 具体的な未対応画面が確認できた company / user remote search 横展開
- 文書セット・外部フォルダ同期設定・文書カタログ管理・文書権限一覧以外の project selection 横展開
- ツリー + 詳細一覧 filter / preset / column width 連携の設計
- Markdown table full RTP integration（#475 親論点）
- viewer 内 table の preference context cue 追加

---

将来対応・保留事項の詳細 → [docs/ToDo.md](docs/ToDo.md)
