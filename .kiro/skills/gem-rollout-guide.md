---
name: "gem展開ガイド"
description: "rtp / rfk / tree_view を新しい画面に展開する際の確認観点・手順・代表 smoke テスト。新規一覧や新規フォームに gem を適用するときに参照する。"
inclusion: manual
---
# Gem Rollout Guide

rtp / rfk / tree_view を未対応画面に展開する際の AI 向け実装ガイド。

---

## 展開の前提条件

1. 対象画面が issue で固定されていること（画面名・field 名・なぜ current support でないかが明記）
2. pinned ref bump とは分離して進めること（Gemfile / Gemfile.lock 変更を含めない）
3. 既存の代表画面で column metadata / filter / preset / smoke が確認済みであること

---

## rails_table_preferences (rtp) 展開チェックリスト

新しい一覧画面に rtp を適用する際の手順:

1. **カラム定義**: モデルの全項目を `columns` 配列に網羅し、主要5〜8列を `default_visible: true` にする
2. **table_key 命名**: `"{resource_name}.index"` をデフォルトにする
3. **Slim テンプレート**: `table_preferences_editor` + `table_preferences_table_tag` の統一パターンに従う（詳細は `rtp-usage.md` skill 参照）
4. **ソート連動**: sortable カラムには controller 側で `order_by` scope を連動させる
5. **フィルタ**: rfk `TableFilterInput` + `render_table_filters` で構成する
6. **Turbo Frame**: フィルタ送信で部分更新（`turbo_frame_tag` で囲む）
7. **CSV/Excel エクスポート**: rtp の表示設定を反映した出力を `respond_to` で切り替える
8. **rparam**: 検索パラメータをセッション記憶する
9. **ページネーション**: pagy で統一する

### 確認観点

- `vite build` が通ること
- table preference 保存がユーザー単位で期待どおり動くこと
- editor の列ON/OFF → テーブル列表示が連動すること
- ソートヘッダークリック → サーバーサイドソートが連動すること
- filter 適用 → Turbo Frame 内の部分更新が正常なこと
- empty state（0件時）が適切に表示されること
- 保存済み設定の復元（ログイン後に設定が維持される）

---

## rails_fields_kit (rfk) 展開チェックリスト

新しいフォームに rfk を適用する際の手順:

1. **ヘルパー選択**: 用途に応じて `rfk_select` / `rfk_combobox` / `rfk_search_field` / `rfk_enum_select` を選ぶ（詳細は `rfk-usage.md` skill 参照）
2. **remote search 設定**: 件数が多い（10件以上）マスタ参照は `rfk_select` + remote search endpoint
3. **selected value 復元**: edit 画面 / validation error 後に selected value が保持されること
4. **placeholder**: 未選択時の案内文を日本語で設定する
5. **候補上限**: remote search の結果件数上限を適切に設定する（通常20件）
6. **Stimulus controller**: gem 提供の `rails-fields-kit--tom-select` controller に寄せる（`new TomSelect(...)` を直接呼ばない）

### 確認観点

- Tom Select / remote search が大量データでも扱いやすいこと
- initial load で selected value が正しく表示されること
- validation error 後の rerender で selected value が復元されること
- placeholder が適切に表示されること
- 検索語入力 → API 呼び出し → 候補表示の動線が正常なこと
- `vite build` が通ること

---

## tree_view 展開チェックリスト

ツリー表示を新しい画面に適用する際の手順:

1. **モデル設計**: `parent_id` 方式の self-referential 関連を使う
2. **Helper / Partial**: `tree_view` の render helper を使い、自前のネスト表示を実装しない
3. **Turbo Frame 連携**: 展開/折りたたみは Turbo Frame と組み合わせて部分読み込みにする
4. **CSS**: `stylesheet_link_tag "tree_view"` でレイアウトに読み込む
5. **展開状態保存**: user ごとの server-side preference による展開/折りたたみ保存
6. **current cue**: 現在位置の badge / `aria-current` による視覚的な強調

### 確認観点

- persisted state（展開状態）が再読み込み後も維持されること
- current node の視覚的 cue が正しいこと
- route context に応じた window offset が適切であること
- Turbo Frame による部分読み込みが正常なこと

---

## 代表 Smoke テスト

各 gem の展開後に確認すべき代表画面と smoke 項目。

| gem | 代表画面 | smoke 項目 |
|-----|---------|-----------|
| rtp | `admin/document_sets` | editor / table / filter / preset / mounted engine save / login redirect / owner-scope isolation |
| rfk | `admin/document_sets` form | initial load / selected value 保持 / placeholder / invalid rerender / Tom Select wiring |
| tree_view | sidebar tree, detail tree | persisted state / window offset / route context / current cue |

新しい画面の展開後は、上記代表画面の smoke 項目と同等の確認を対象画面でも行う。

---

## 展開順序の原則

1. **rtp から着手**: 一覧画面がある場合はまず rtp を適用する（表示基盤）
2. **rfk は rtp と同時可**: 一覧の filter で rfk を使う場合は rtp と同一 PR で入れてよい
3. **rfk 単独**: フォーム画面のみの場合は rfk 単独で進める
4. **tree_view**: 階層構造表示が必要な場合に適用（rtp / rfk とは独立）
5. **Stimulus 化**: 既存の素 JS を触るタイミングで controller 化する。新規 JS を追加する場合は最初から Stimulus controller にする

---

## gem 側に不足がある場合

- それぞれの gem リポジトリへ upstream issue を作成する
- docs-portal 側の issue / PR と upstream issue を混ぜない
- upstream の未 merge PR / 未着地 API を durable contract にしない
- 境界判断の詳細は `.kiro/steering/internal-ui-gem-boundaries.md` を参照
