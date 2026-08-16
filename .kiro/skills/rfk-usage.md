---
name: "rfk実装ガイド"
description: "rails_fields_kit (rfk) を使ったフォームフィールドの具体的な実装パターン。select/combobox/multi_select/tags/enum_selectの書き方、search_optionsとの連携。"
---
# rfk (rails_fields_kit) 実装ガイド

## Stimulus 登録

```typescript
// app/frontend/controllers/index.ts
import { TomSelectController as RailsFieldsKitTomSelectController } from "rails_fields_kit"
application.register("rails-fields-kit--tom-select", RailsFieldsKitTomSelectController)
```

---

## ヘルパー一覧と選択基準

| 場面 | ヘルパー | 判断基準 |
|------|---------|---------|
| マスタ参照（単一、選択肢少数） | `rfk_select` | collection を直接渡せる程度（~10件） |
| マスタ参照（単一、API検索） | `rfk_combobox` | 選択肢が多い or インクリメンタルサーチが必要 |
| enum 属性 | `rfk_enum_select` | ActiveRecord enum を日本語ラベルで表示 |
| 複数選択（既存マスタ） | `rfk_multi_select` | N対N紐づけ、タグ的な既存値の複数選択 |
| タグ入力（新規作成可） | `rfk_tags` | ユーザーが自由にタグを追加できる |
| フリーワード検索 | `rfk_search_field` | 検索フォームのキーワード入力 |
| 金額入力 | `rfk_money_field` | 通貨prefix + decimal inputmode |
| 割合入力 | `rfk_percent_field` | % suffix + decimal inputmode |

---

## 典型パターン

### rfk_search_field（フリーワード検索）

```erb
<%= form.rfk_search_field :query,
  value: params[:query],
  placeholder: "キーワードで検索",
  wrapper: false,
  html: { class: "search-input", aria: { label: "キーワードで検索" } } %>
```

既存のフォームレイアウト内で入力要素だけを描画する場合は `wrapper: false` を指定し、入力要素の class / data / aria 属性は `html:` に渡す。

### rfk_select（検索フィルタ用）

```slim
= f.rfk_select :status,
  collection: Status::OPTIONS.map { |s| [s.label, s.value] },
  include_blank: "すべて",
  selected: params[:status],
  allow_clear: true
```

**ルール: 検索フィルタの `rfk_select` には必ず `allow_clear: true` を付ける。**

### rfk_select（フォーム入力用）

```slim
= f.rfk_select :project_id,
  collection: Project.order(:name),
  collection_value_method: :id,
  collection_label_method: :name,
  include_blank: "選択してください"
```

### rfk_combobox（フォーム入力用、ID選択）

```slim
= f.rfk_combobox :user_id,
  url: search_options_path("users"),
  selected_url: search_options_path("users"),
  selected: record.user_id,
  value_field: "value",
  label_field: "label",
  query_param: "q",
  selected_param: "id",
  placeholder: "担当者を検索",
  include_blank: "選択してください",
  min_length: 0,
  preload: true
```

### rfk_combobox（検索フィルタ用、テキスト部分一致）

マスタ件数が多い対象（顧客・担当者等）の検索フィルタはこのパターンを使う。

```slim
= f.rfk_combobox :customer,
  url: search_options_path("customers"),
  selected_url: search_options_path("customers"),
  selected: params[:customer],
  value_field: "label",
  label_field: "label",
  query_param: "q",
  selected_param: "label",
  placeholder: "顧客を検索",
  include_blank: "すべて",
  min_length: 0,
  preload: true,
  allow_clear: true,
  free_text: true
```

特徴:
- `value_field: "label"` — 選択時にテキスト名が値になる
- `free_text: true` — 候補から選ばなくても入力テキストがそのまま送信される
- `allow_clear: true` — × ボタンでクリア可能

### rfk_enum_select

```slim
= f.rfk_enum_select :status, include_blank: "選択してください"
```

### rfk_multi_select

```slim
= f.rfk_multi_select :tag_ids,
  collection: Tag.active.ordered,
  collection_value_method: :id,
  collection_label_method: :name,
  selected: f.object.tag_ids,
  placeholder: "タグを選択",
  plugins: ["remove_button"]
```

### rfk_tags（新規作成可）

```slim
= f.rfk_tags :tag_list,
  url: search_options_path("tags"),
  value_field: "value",
  label_field: "label",
  query_param: "q",
  create: true,
  placeholder: "タグを入力"
```

### rfk_money_field / rfk_percent_field

```slim
= f.rfk_money_field :unit_price, currency: "¥"
= f.rfk_percent_field :tax_rate
```

---

## search_options エンドポイント

rfk の combobox / multi_select は `/search_options/:resource` へJSONリクエストを送る。

```
GET /search_options/users?q=松尾
→ [{ "value": 1, "label": "松尾春人" }, ...]

GET /search_options/users?id=1
→ [{ "value": 1, "label": "松尾春人" }]  (selected_url用)
```

新しいマスタを追加する場合は SearchOptionsController に `when "リソース名"` を追加する。

---

## 検索フィルタでの rfk（TableFilterInput）

一覧画面のフィルタは `RailsFieldsKit::TableFilterInput` で宣言する:

```ruby
filter_columns = [
  { key: "_q",
    filter: RailsFieldsKit::TableFilterInput.search_field(:q, placeholder: "キーワード"),
    filter_html: { label: "キーワード", col_class: "col-lg-3 col-md-6" } },
  { key: "_status",
    filter: RailsFieldsKit::TableFilterInput.select(:status, collection: [...], include_blank: "すべて"),
    filter_html: { label: "状態" } },
]
```

ビューでは `render_table_filters(f, filter_columns)` で一括描画する。

---

## 依存フィルタ（rfk-dependent-filter）

親フィールドの値に応じて子フィールドのURLと選択肢を更新する。rfk helperが生成する入力要素へdata属性を渡すときは、top-levelの`data:`ではなく`html: { data: ... }`を使う:

```slim
div data-controller="rfk-dependent-filter"
  = f.rfk_combobox :project_id,
    url: search_options_path("projects"),
    html: { data: { rfk_dependent_filter_target: "source", action: "rails-fields-kit--tom-select:change->rfk-dependent-filter#refresh" } }
  = f.rfk_combobox :document_id,
    url: search_options_path("documents"),
    html: { data: { rfk_dependent_filter_target: "field" } }
```

- rfkの`rails-fields-kit--tom-select:change`イベントを使い、アプリ側でTom Selectを再初期化しない。
- URLは`data-rails-fields-kit--tom-select-url-value`を更新する。rfk controllerは候補取得時に現在値を読む。
- 親値が変わった子フィールドは、`element.tomselect.clear(true)`と`clearOptions()`で選択値・旧候補を破棄する。
- 候補取得不可でも入力を継続する必要があるフィールドには`free_text: true`を指定する。

---

## フォーム入力 vs 検索フィルタの使い分け

| ヘルパー | 用途 | allow_clear |
|---------|------|-------------|
| `rfk_combobox` フォーム入力 | ID選択 | 任意 |
| `rfk_combobox` 検索フィルタ | テキスト部分一致 | **必須** |
| `rfk_select` フォーム入力 | 固定選択肢 | 任意 |
| `rfk_select` 検索フィルタ | 固定選択肢で絞り込み | **必須** |

---

## CSS: Tom Select の改行防止

Tom Select のデフォルト CSS では `.ts-control` が `flex-wrap: wrap` のため、combobox で値を選択すると input が次の行に折り返される。

`app/frontend/entrypoints/tom_select_overrides.css` で以下を上書きしている:

- `.ts-wrapper.single .ts-control` — `flex-wrap: nowrap` + `overflow: hidden`
- `.ts-wrapper .ts-control > .item` — `white-space: nowrap` + `text-overflow: ellipsis`
- `.ts-wrapper.has-items .ts-control > input` — `min-width: 1px` で折り返し防止
- `.ts-wrapper.single.has-items .ts-control > input` — `width: 0` + `flex: 0 0 0px` で完全に縮小

このファイルは `application.ts` で `tom-select.css` の直後に import される。新しい rfk フィールドを追加する際、追加の CSS は不要（自動で適用される）。

### カスタマイズが必要な場合

- テーブルセル内などコンパクト表示が必要な場合は `.ts-control` の `min-height` / `padding` / `font-size` をスコープ付きで調整する
- モーダルやフローティングパネル内で使う場合は `body > .ts-dropdown` の `z-index` を上げる

---

## NGパターン

- `f.select` / `f.collection_select` を使う → rfk ヘルパーに置き換える
- ネイティブの `<select multiple>` を使う → `rfk_multi_select` に置き換える
- `enum_options_for` + `f.select` の組み合わせ → `rfk_enum_select` に置き換える
- TomSelect を直接 JS で初期化する → rfk の Stimulus コントローラー経由で使う
- 検索フィルタの rfk に `allow_clear: true` を付けない → 条件解除できない
