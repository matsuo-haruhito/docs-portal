# ROADMAP

この文書は **gem 展開・Stimulus 化・UI基盤** の短期アクションと候補を扱う。

- ここに書くもの: 次に着手できる具体的な技術タスク、進行中の展開状況、近いうちに判断する候補
- ここに書かないもの: 完了済み・close 済み Issue、将来の検討事項、人間判断待ち、未起票の要望
- 将来対応・保留事項は [ToDo](docs/ToDo.md) を正本にする

---

## 現在地

- `tree_view`: 文書ツリー sidebar、current cue、server-side 展開状態保存、文書詳細本文側 state cueへ適用済み
- `rails_table_preferences`: Rails の通常一覧で列設定・ソート・フィルタを担当する
- `rails_fields_kit`: remote search、combobox、picker を担当する
- Vite + Stimulus: gem JS entrypoint と app controller の読み込み基盤を使い、Turbo > Stimulus > 素の JavaScript の優先順位を維持する
- Docusaurus Markdown preview table: `rails_table_preferences` へ直接接続せず、app 側 preview tool が列幅・sticky・検索・copy・export・状態保存を担当する
- `preview-tools` bridge: 退役済み。専用 Stimulus controller が各 preview helper を refresh する

## 次のアクション

- rtp 新規一覧展開: 未展開の具体的な index 画面、column metadata、filter、CSV 契約、代表 request spec を 1 画面単位で固定してから着手する
- rfk 横展開: 未対応画面の具体的な field と selected value / validation rerender / remote search 契約を特定してから着手する
- Stimulus 化: 既存の素 JavaScript を変更するタイミングで、対象 DOM に閉じた controller へ移す。`application.js` に `querySelectorAll` とイベント登録を直接増やさない
- tree と table state: current / expanded と column / filter / sort は独立した責務を維持する。具体的な不足が再現するまで自動連携を追加しない
- Markdown preview table: 現行 app 側 fallback の stable key、Turbo 再描画後 refresh、keyboard / cleanup、export を回帰確認する。full rtp 統合を進行中タスクとして扱わない

## preview controller の現行構成

専用 controller がそれぞれ helper refresh または DOM 操作を担当する。

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
- `preview-table-resizer`

新しい preview UI は、Turbo だけで完結できるかを先に確認し、ブラウザ内の小さな状態管理が必要な場合だけ専用 Stimulus controller に閉じる。

## 候補を追加する条件

次を満たしたものだけ短期候補へ追加する。

- 対象画面または field が 1 つに特定されている
- current behavior の不足と再現条件がある
- request spec、source guard、manual browser evidence のどこで検証するかを分けられる
- gem 側変更が必要な場合は upstream public API と host app 責務を分けられる
- rollback 方法を記録できる

具体的な利用例がない company / user remote search の横展開、全画面一括移行、Markdown preview table の full rtp 統合は active queue に置かない。

展開時の確認観点、代表 smoke、gem 不足時の upstream issue 運用は `.kiro/skills/gem-rollout-guide.md` に集約する。
