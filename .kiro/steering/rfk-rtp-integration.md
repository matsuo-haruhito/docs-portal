# rfk / rtp 利用方針

inclusion: always

---

## skill の追従ルール

rfk / rtp の使い方に変更があった場合（実装パターンの追加、API変更等）、該当する skill ファイルも必ず同時に更新すること。

- rfk 関連の変更 → `.kiro/skills/rfk-usage.md` を更新
- rtp 関連の変更 → `.kiro/skills/rtp-usage.md` を更新
- 両方に影響する変更 → 両方を更新

ユーザーが「こうしてほしい」と指示した使い方の変更も、コード修正と同時に skill へ反映する。

---

## フォームフィールドは rfk で描画する

フォームフィールドの選択系・入力系はすべて `rails_fields_kit`（rfk）ヘルパーで描画する。

- `f.select` / `f.collection_select` → `rfk_select` or `rfk_combobox`
- `f.select` + enum → `rfk_enum_select`
- `<select multiple>` → `rfk_multi_select`
- タグ入力 → `rfk_tags`
- フリーワード検索 → `rfk_search_field`

**具体的なコード例とオプションは `rfk実装ガイド` skill を参照。**

---

## 一覧テーブルは rtp で描画する

すべての一覧画面（index）のテーブルに `rails_table_preferences`（rtp）を適用する。

### 必須構成

- テーブル描画: `table_preferences_table_tag`
- 列設定: `table_preferences_editor`
- ソート: 現行RTP v1.0.0ではserver-side sort未提供のため `sortable: true` は指定しない
- フィルタ: rfk `TableFilterInput` + `render_table_filters`
- Turbo Frame: フィルタ送信で部分更新

**具体的な実装パターンとチェックリストは `rtp実装ガイド` skill を参照。**

---

## ツリー表示は tree_view で描画する

親子関係・階層構造の表示には `tree_view-rails` を使う。

### ルール

- 自前のネスト表示を実装しない
- 展開/折りたたみは Turbo Frame と組み合わせて部分読み込みにする
- CSSは gem baseline `tree_view.css` + host override `docs_portal_tree_view.css` を読み込む
- path-based ツリーには `PathTreeBuilder`、異種ルートには `GraphAdapter` を使う
- 具体的な実装パターンは `tree_view実装ガイド` skill を参照

---

## フィルタの使い分け

| フィルタ種類 | 配置場所 | 実装 | 適用場面 |
|-------------|---------|------|---------|
| フィルタカード | テーブル上部 | rfk `TableFilterInput` + `render_table_filters` | 複合条件検索、rfk ウィジェットが必要な場面 |
| ヘッダーフィルタ | 列ヘッダーの▾ボタン | gem ネイティブ filter metadata | カラム単位の即時フィルタ（text/select） |

---

## 検索フィルタレイアウト

フィルタフィールドの幅・並び順・行分割は `検索フィルタレイアウトガイド` skill に従う。
