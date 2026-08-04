---
name: "rtp実装ガイド"
description: "rails_table_preferences (rtp) を使った一覧テーブルの具体的な実装パターン。カラム定義、ソート連携、フィルタ（rfk TableFilterInput）、Turbo Frame、エクスポート。"
---
# rtp (rails_table_preferences) 実装ガイド

## Stimulus 登録

```typescript
// app/frontend/controllers/index.ts
import RailsTablePreferencesController from "rails_table_preferences/controller"
application.register("rails-table-preferences", RailsTablePreferencesController)
```

---

## 一覧画面の統一パターン

```slim
/--- 1. 変数定義 ---
- table_key = "xxx.index"
- columns = [...]
- filter_columns = [...]

/--- 2. ページヘッダー ---
header
  h1 一覧タイトル
  = link_to "新規登録", new_xxx_path

/--- 3. フィルタカード ---
= form_with(url: xxx_path, method: :get, data: { turbo_frame: "xxx-list", turbo_action: "advance" }) do |f|
  = render_table_filters(f, filter_columns)
  = f.submit "検索"
  = link_to "条件クリア", xxx_path(clear_filters: 1)

/--- 4. リスト部（Turbo Frame） ---
= turbo_frame_tag "xxx-list", target: "_top" do
  = table_preferences_editor(table_key: table_key, columns: columns)

  = table_preferences_table_tag(table_key: table_key, columns: columns, settings: ...) do
    thead
      tr
        - columns.each do |col|
          th data-rails-table-preferences-column-key=col[:key] = col[:label]
    tbody
      - @records.each do |record|
        tr
          - columns.each do |col|
            td data-rails-table-preferences-column-key=col[:key]

  / フッター
  nav
    / pagy ページネーション
    = link_to "CSV", xxx_path(request.query_parameters.merge(format: :csv))
```

---

## カラム定義

```ruby
columns = [
  { key: "title", label: "タイトル", sortable: true },
  { key: "status", label: "状態", sortable: true, default_width: 100 },
  { key: "project", label: "案件", sortable: true, default_width: 180 },
  { key: "updated_at", label: "更新日時", sortable: true, default_width: 130 },
  { key: "notes", label: "備考", default_visible: false, overflow: :wrap },
]
```

### カラム定義オプション

| オプション | 説明 |
|-----------|------|
| `key` | カラム識別子（th/td の data属性と一致させる） |
| `label` | 日本語ヘッダー |
| `sortable: true` | ソートクリック有効 |
| `default_visible: false` | 初期非表示 |
| `default_width` | 初期列幅（px） |
| `overflow: :ellipsis` | 省略表示（デフォルト） |
| `overflow: :wrap` | 折り返し表示 |

### 列定義の方針

- テーブルの**ほぼ全カラム**を columns に含める
- 主要 5〜8 列を `default_visible: true`（デフォルト）、残りを `default_visible: false`
- デフォルト非表示にする基準: ID系、タイムスタンプ、コード値（名称カラムがある場合）

---

## フィルタ定義（rfk TableFilterInput 連携）

```ruby
filter_columns = [
  { key: "_q",
    filter: RailsFieldsKit::TableFilterInput.search_field(:q, placeholder: "キーワード"),
    filter_html: { label: "キーワード", col_class: "col-lg-3 col-md-4" } },
  { key: "_status",
    filter: RailsFieldsKit::TableFilterInput.select(:status, collection: [...], include_blank: "すべて"),
    filter_html: { label: "状態", col_class: "col-lg-2 col-md-3" } },
  { key: "_project",
    filter: RailsFieldsKit::TableFilterInput.combobox(:project,
      url: search_options_path("projects"),
      value_field: "label", label_field: "label",
      query_param: "q", selected_param: "label",
      placeholder: "案件を検索", include_blank: "すべて",
      min_length: 0, preload: true, allow_clear: true, free_text: true),
    filter_html: { label: "案件", col_class: "col-lg-3 col-md-4" } },
]
```

### TableFilterInput ファクトリメソッド

| メソッド | 用途 |
|---------|------|
| `.search_field` | フリーワード検索 |
| `.select` | 固定選択肢 |
| `.combobox` | API検索 + 自由入力 |
| `.multi_select` | 複数選択 |
| `.enum_select` | enum 選択肢 |

---

## ソートの仕組み

### th にはラベルだけ書く。手動でソートリンクを作らない。

rtp Stimulus controller が:
1. `sortable: true` のカラムの th クリックを検知
2. 昇順 → 降順 → 解除 を循環
3. `Turbo.visit` で URL に sort/direction を付与してナビゲーション

### サーバーサイド

```ruby
def index
  scope = Model.search(params)
  scope = apply_sort(scope)

  respond_to do |format|
    format.html { @pagy, @records = pagy(scope) }
    format.csv { send_csv(scope) }
  end
end

private

def apply_sort(scope)
  allowed = %w[title status project_name updated_at created_at]
  key = params[:sort].to_s.delete_prefix("-")
  key = "updated_at" unless allowed.include?(key)
  direction = params[:direction] == "desc" ? :desc : :asc
  scope.order(key => direction)
end
```

---

## Turbo Frame の効果

- フィルタフォーム送信でリスト部分だけを部分更新
- TomSelect が destroy されない（選択値が維持される）
- `turbo_action: "advance"` でURL履歴も更新（戻るボタン・ブックマーク対応）
- ソートクリックも `Turbo.visit` で遷移

---

## エクスポート連携

```ruby
respond_to do |format|
  format.html { @pagy, @records = pagy(scope) }
  format.csv { send_csv_export(scope.except(:limit, :offset)) }
end
```

- `request.query_parameters.merge(format: :csv)` で検索・ソート条件を維持したままエクスポート
- ページネーション解除（`.except(:limit, :offset)`）で全件出力
- CSV: BOM付きUTF-8（Excel互換）

---

## チェックリスト: 新しい一覧画面

1. table_key, columns, filter_columns をビュー冒頭にまとめる
2. 全カラムを列挙、主要5〜8列を default_visible、ソート対象に `sortable: true`
3. filter_columns に `TableFilterInput` を定義、`render_table_filters` で描画
4. Turbo Frame でリスト部を囲む
5. `table_preferences_table_tag` で描画
6. th / td に `data-rails-table-preferences-column-key` を付与
7. th にはラベルのみ（ソートリンク不要）
8. 列設定エディターをテーブル上に配置
9. フッターでページネーション + CSV
10. コントローラーで `respond_to` + ソート + エクスポート

---

## NGパターン

- th 内に手動でソートリンクを書く → rtp controller に任せる
- rtp を使わず手書きで `<table>` を描画する
- `th` / `td` に `data-rails-table-preferences-column-key` を付け忘れる
- フィルタフォームに sort/direction の hidden field を手動で書く（`render_table_filters` が自動出力）
- ソート対応カラムの key とコントローラーの allowed 名が不一致
