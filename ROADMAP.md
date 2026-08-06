# ROADMAP

この文書は **gem 展開・Stimulus 化・UI基盤** の短期アクションと候補を扱う。

- ここに書くもの: 次に着手する具体的な技術タスク、進行中の展開状況、未確定だが近いうちに判断する候補
- ここに書かないもの: 将来の検討事項、人間判断待ち、未起票の要望 → [docs/ToDo.md](docs/ToDo.md)

---

## 現在地サマリ

- tree_view: 文書ツリー sidebar / current cue / server-side 展開状態保存 / 文書詳細本文側 state cue（適用済み画面: 2）。tree current cue と詳細一覧 table/filter state は独立した責務として非連携（[state cue inventory](docs/internal-ui-gem-state-cue-inventory.md) 参照）
- rails_table_preferences: 一覧画面の列設定・ソート・フィルタ（適用済み画面: 9）
- rails_fields_kit: remote search / combobox / picker（適用済み画面: 9）
- Vite + Stimulus: gem JS entrypoint 読み込み基盤確立、Turbo > Stimulus > 素 JS の方針定着
- DocusaurusSiteRenderer: table rewrite による DOM 境界 metadata 付与（current support）

## 次のアクション

- rtp 新規一覧展開: 既存9画面の column metadata / filter / preset 確認完了後、未展開候補を issue 上で固定して着手
- rfk 横展開: 未対応画面の具体的な画面名・field 名を特定し issue を起票してから着手（代表画面は current support 済み）
- tree + table state 連携: 文書ツリー state（current / expanded）と詳細一覧 table/filter state は独立した責務として扱い、自動連携は導入しない（#3741 で境界整理済み）。将来の viewer table preference context（#4071 / #475）のみ連携候補として残す
- ResourceTableRenderState viewer 反映: #4071 で docs-only 境界固定後、guard 方式を別 issue で決定
- Stimulus 化継続: 既存素 JS を触るタイミングで controller 化。Markdown table の full RTP 統合は #475 に残す

## preview-tools bridge 退役

`preview-tools` bridge は移行用の入口として退役済み。bridge 再導入や空 controller の維持は current support として扱わない。

専用 controller がそれぞれ helper refresh を担当:

- `markdown-preview-table-tools`
- `pdf-preview-tools`
- `image-preview-tools`
- `structured-preview-tools`
- `csv-preview-tools`
- `archive-preview-tools`
- `document-file-list-search`
- `markdown-preview-document-search`
- `markdown-preview-codeblock-tools`
- `site-viewer-iframe-height`

`application.js` に `querySelectorAll` とイベント登録を直接増やさない。

## 候補（未確定）

- 具体的な未対応画面が確認できた company / user remote search 横展開
- 文書セット・外部フォルダ同期設定・文書カタログ管理・文書権限一覧以外の project selection 横展開
- ツリー + 詳細一覧 filter / preset / column width 連携の設計 → #3741 で非連携と結論。viewer table preference context のみ #4071 で検討
- Markdown table full RTP integration（#475 親論点）
- viewer 内 table の preference context cue 追加

展開時の確認観点・方針の詳細（vite build 通過、preference 保存確認、代表 smoke、gem 不足時の upstream issue 運用）は `.kiro/skills/gem-rollout-guide.md` に集約。

---

将来対応・保留事項の詳細 → [docs/ToDo.md](docs/ToDo.md)
