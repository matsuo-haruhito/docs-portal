---
name: "rtp実装ガイド"
description: "docs-portalでrails_table_preferences (rtp) を使うための標準実装。列設定モーダル、列幅・列順の双方向同期、フィルタ、Turbo Frame、エクスポート。"
---
# rtp (rails_table_preferences) 実装ガイド

## docs-portalでの標準

このリポジトリでは、列設定をページ内へ直接展開せず、`ColumnSettingsComponent` が提供するnative `<dialog>`モーダルをRTPの標準UIとする。新しい一覧画面も既存画面の改修も、この構成をそのまま再利用し、画面固有の列設定UIを作らない。

### 実装の正本

| 責務 | 正本 |
|---|---|
| 列設定ボタン・dialog・editor描画 | `app/components/column_settings_component.rb` / `.html.slim` |
| dialogの開閉・focus復元 | `app/frontend/controllers/column_settings_dialog_controller.ts` |
| gem controllerのhost補完・table/editor同期 | `app/frontend/controllers/rails_table_preferences_controller.ts` |
| controller登録 | `app/frontend/entrypoints/application.ts` |
| modal・editor・tableの見た目 | `app/frontend/entrypoints/application.css` |
| package-root exportの型補完 | `app/frontend/types/rails_table_preferences.d.ts` |

### 標準UIの構成

- 一覧上には歯車アイコン付きの「列設定」ボタンだけを置き、クリックでmodalを開く
- 列設定ボタンはPrimary CTAではなくneutral outline / ghostのUtilityとして表示し、件数と同じList meta領域へ置く
- modal上部には一覧固有の日本語タイトルと「閉じる」ボタンを表示する
- modal本体にはgemのeditorを置き、保存済み設定、設定名、標準設定、列検索、列一覧を表示する
- 各列rowには日本語列名を必ず表示し、DnD handle、上下移動、表示checkbox、表示順、列幅、省略文字数を同じ行に配置する
- 操作領域はmodal下部に維持し、列一覧が長い場合はmodal本体だけをスクロールさせる
- desktopは最大72rem・最大80vh、mobileはviewport内に収める。ページ全体をeditorで押し広げない
- `ColumnSettingsComponent`へ渡すtitleは「文書マスター一覧の表示設定」のように対象一覧が分かる日本語とする

## Stimulus 登録

現行docs-portalではpackage-root public exportを入口にし、table→editor間の列幅・列順同期だけをhost controllerへ閉じ込める。gem側でpreset target不足のguardは実装済みのため、host側で重複overrideしない。

```typescript
// app/frontend/controllers/rails_table_preferences_controller.ts
import { RailsTablePreferencesController as BaseController } from "rails_table_preferences"

export default class extends BaseController {
  // docs-portal固有: resize/DnD完了後に同じtable_keyのeditorへwidth/orderを同期する
  // docs-portal固有: editor dialog開閉時にpairedTableから列幅を取得する
}

// app/frontend/entrypoints/application.ts
import RailsTablePreferencesController from "../controllers/rails_table_preferences_controller"
application.register("rails-table-preferences", RailsTablePreferencesController)
```

- controllerは1回だけregisterする
- gem内部pathへ依存せずpackage-root public exportを使う
- gem側でpreset target不在時のguardは実装済みのため、host controllerにtarget guard overrideを追加しない
- host controllerに残す責務はdocs-portal固有のUXのみ: table/editor間の列幅・列順双方向同期、placeholder追加

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
  .list-meta
    p = "全#{@pagy.count}件"
    = render ColumnSettingsComponent.new(
      table_key: table_key,
      columns: columns,
      settings: table_settings,
      title: "一覧の表示設定"
    )

  = table_preferences_table_tag(
    table_key: table_key,
    columns: columns,
    settings: table_settings,
    scroll_wrapper: true,
    wrapper_options: {
      class: "table-scroll",
      role: "region",
      tabindex: 0,
      aria: { label: "一覧タイトル" }
    }
  ) do
    thead
      tr
        - columns.each do |col|
          th data-rails-table-preferences-column-key=col[:key] = col[:label]
    tbody
      - @records.each do |record|
        tr
          - columns.each do |col|
            td data-rails-table-preferences-column-key=col[:key]

  / 2ページ以上の場合だけページネーション
  - if @pagy.pages > 1
    nav aria-label="一覧ページ"
      / pagy ページネーション

  / エクスポートはページャーと独立
  .actions
    = link_to "CSV", xxx_path(request.query_parameters.merge(format: :csv))
```

### 列設定の開閉

- 一覧Viewから `table_preferences_editor` を直接描画せず、host appの `ColumnSettingsComponent` を使う
- Componentはnative `<dialog>`を使い、初期状態では閉じる。editorのDOMはdialog内に保持して保存対象から外さない
- dialogはEscape、背景クリック、明示的な閉じるボタンで閉じ、close後は起動ボタンへfocusを戻す
- editorとtableには同じ `table_key`、`columns`、`settings` を渡す
- desktopは最大72rem・最大80vh、mobileはviewport内に収め、列一覧をdialog内部でscrollする
- 各editor rowは「DnD」「上下移動」「表示+日本語列名」「順」「幅」「省略」をcompact gridで表示する。列名をiconやkeyだけに置き換えない
- globalな `input { width: 100% }` に任せず、number inputの幅をscope CSSで制御する
- modal下部の操作群は列一覧のscroll領域外に維持し、「全列表示」「全列非表示」「適用」「保存」「別名で保存」「削除」「テーブル初期設定に戻す」を常に操作できる状態にする
- 画面ごとのmodal初期化を追加せず、共通 `column-settings-dialog` Stimulus controllerを使う

### `ColumnSettingsComponent` の利用例

```slim
= render ColumnSettingsComponent.new(
  table_key: table_key,
  columns: columns,
  settings: table_settings,
  title: "文書マスター一覧の表示設定",
  description: "表示する列、表示順、列幅を変更できます。"
)
```

- `description` は画面へ長文表示せず、Componentのhelp tooltipとして渡す
- 呼び出し側で `<dialog>`、close button、editor wrapperを再実装しない
- ComponentのDOM classと `column-settings-dialog` controllerを画面固有CSS/JSで上書きしない

### table操作とeditorの双方向同期

- editorから「適用」した設定はgemのsettings syncでtableへ反映する
- table headerのresize/DnD完了時はhost controllerが同じ `table_key` のeditor controllerへcolumns settingsを同期する
- 列設定dialogを開いた時もtable側のwidth/orderを取り込み、保存で古いeditor値がtable操作を上書きしないようにする
- host controllerはgemの `autoFitColumnFromHandle` と `endTableColumnDrag` の完了後だけ同期し、resize/DnD本体を再実装しない
- dialog controllerはopen後に `column-settings-dialog:opened` を通知し、host RTP controllerはそのeventでtableからeditorへ同期する
- 同期先は同一 `table_key` のeditorだけに限定する。同一ページに複数tableがあっても設定を混ぜない
- editor rowのDnDまたは上下移動後は `order` inputを更新し、「適用」でtable headerとbody cellを同じ順に移動する
- table headerのresize後は列のinline widthとeditorの「幅」inputが同じ値になることを確認する
- table rootでpreset target不足のconsole error、`aria-busy="true"`残留、disabled resize handleがないことをbrowser smokeで確認する

### 実ブラウザで必ず確認する操作

1. 「列設定」でdialogが開き、全rowに日本語列名が表示される
2. editorの「幅」を変更して「適用」すると対象列の幅が変わる
3. editor rowをDnDまたは上下ボタンで移動して「適用」するとtableの列順が変わる
4. table headerのresize handleをdragすると列幅が変わり、dialogを再度開いた時に「幅」へ同期される
5. table headerをDnDすると列順が変わり、dialogを再度開いた時にrow順へ同期される
6. 「保存」後にreloadしても列表示・列順・列幅が復元される
7. Escape、背景クリック、閉じるボタンでdialogが閉じ、列設定ボタンへfocusが戻る
8. browser consoleにStimulus errorがなく、table/editorの操作中以外は `aria-busy="false"` または属性なしである
9. 1440pxで主要列と右端の操作列を確認でき、操作buttonがscroll wrapperやviewport端で切れない
10. 1ページだけの場合はpager nav、disabledな前後操作、「1ページのみ」を表示せず、2ページ以上ではtable後方にpagerを表示する
11. CSV / Excel等のexportはpagerの有無にかかわらず、検索・ソート条件を保持して利用できる

### 横スクロールとtable layout

- 横長一覧は `table_preferences_table_tag` の公開オプション `scroll_wrapper: true` を使う
- `wrapper_options` には `class: "table-scroll"`, `role: "region"`, `tabindex: 0`, 一覧を特定できる `aria-label` を指定する
- `<table>` 本体へ `display: block` や `overflow-x: auto` を指定しない。native table layoutを壊すと列幅、固定列、resizeの計算が不安定になる
- `table-layout: fixed` はtable本体へ適用し、overflowはwrapperが担当する
- table headerはneutral gray、bodyはwhite、hoverは薄いneutral blueを基本とし、Orange borderや強いshadowを一覧tableへ使わない
- 操作列は110pxへ一律固定せず、実際の許可済み操作数とラベルに合わせる。icon-only操作にはBootstrap Icons、対象を特定できる`aria-label`と`title`を付ける
- 保存済み列幅を尊重しつつ、1440pxで右端の操作列まで到達でき、buttonが切れないことをbrowser smokeで確認する

---

## カラム定義

```ruby
columns = [
  { key: "title", label: "タイトル" },
  { key: "status", label: "状態", default_width: 100 },
  { key: "project", label: "案件", default_width: 180 },
  { key: "updated_at", label: "更新日時", default_width: 130 },
  { key: "notes", label: "備考", default_visible: false, overflow: :wrap },
]
```

### カラム定義オプション

| オプション | 説明 |
|-----------|------|
| `key` | カラム識別子（th/td の data属性と一致させる） |
| `label` | 日本語ヘッダー |
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

### 現状: sortable: true は使用しない

採用中の RTP v1.0.0 では、`sortable: true` を指定するとヘッダーに昇順・降順 indicator が表示されクリック可能になるが、**URL遷移やサーバーリクエストは発生しない**。つまり visual indicator が変化するだけで、実際のデータ行順は変わらない。

この不一致を防ぐため、docs-portal では全画面で `sortable: true` を付与しない。

### ルール

- 列定義に `sortable: true` を指定しない
- th にはラベルだけ書き、手動ソートリンクも置かない
- gem内部pathのimport、手書きのheader click handler、画面ごとのsort linkで補完しない
- 各controllerではビジネス要件に即した固定の `.order(...)` を使う

### 将来: server-side sort の接続

RTP upstream が公開 navigation contract（sort click → URL遷移）を提供した場合に限り、以下のパターンで server-side sort を接続する。

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

upstream contract が提供されるまで、`sortable: true` は追加しない。

---

## Turbo Frame の効果

- フィルタフォーム送信でリスト部分だけを部分更新
- TomSelect が destroy されない（選択値が維持される）
- `turbo_action: "advance"` でURL履歴も更新（戻るボタン・ブックマーク対応）
- ソートのURL遷移は採用中rtp versionの公開contractが提供する場合だけ接続する

---

## Header Filter metadata は使用しない

RTP の列定義に `filter: { type: :select, param: ... }` を指定するとヘッダーに filter UI ボタン（▾）が表示されるが、docs-portal の RTP controller にはfilter state → GET query への反映処理がない。

そのため、filter UI を操作しても実際の検索結果は変わらない。

### ルール

- 列定義に `filter:` metadata を指定しない
- 検索の正本は既存の GET 検索フォーム（rfk ヘルパー + `form_with`）とする
- controller 側で `params[:xxx]` を読んで ActiveRecord query に適用するパターンを維持する
- 同一条件を2つの独立した state（フォーム + RTP header filter）で管理しない

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
2. 全カラムを列挙、主要5〜8列を default_visible（`sortable: true` は現行版では使用しない）
3. filter_columns に `TableFilterInput` を定義、`render_table_filters` で描画
4. Turbo Frame でリスト部を囲む
5. `table_preferences_table_tag` で描画し、横長一覧は `scroll_wrapper: true` とフォーカス可能なwrapperを指定
6. th / td に `data-rails-table-preferences-column-key` を付与
7. th にはラベルのみ。`sortable: true` は RTP upstream が server-side sort navigation を公開するまで付けない
8. `ColumnSettingsComponent` を件数と同じList meta領域へUtilityとして配置し、直接editorや画面固有dialogを描画しない
9. editor rowに日本語列名が表示され、table/editorの幅・順序が双方向同期することをbrowserで操作確認
10. 操作列は実操作数に合わせ、icon-only buttonへBootstrap Icons、`aria-label`、`title`を付ける
11. 2ページ以上の場合だけtable後方にページネーションを表示し、CSV等のエクスポートは独立して配置する
12. 1440pxで主要列と操作列が切れず、横スクロールwrapperへkeyboard focusできることを確認する
13. コントローラーで `respond_to` + 固定order + エクスポート

---

## NGパターン

- 一覧Viewから `table_preferences_editor` を直接描画する
- 列設定をページ内の常時展開panelやnative `<details>`で実装する
- 画面ごとに独自の列設定modal、開閉JavaScript、RTP controllerを追加する
- editor rowから日本語列名を省き、key・checkbox・数値だけを表示する
- table headerのresize/DnD後にeditorへ同期せず、古いeditor値で上書き可能な状態にする
- th 内に手動でソートリンクを書く → rtp controller に任せる
- rtp を使わず手書きで `<table>` を描画する
- `th` / `td` に `data-rails-table-preferences-column-key` を付け忘れる
- フィルタフォームに sort/direction の hidden field を手動で書く（`render_table_filters` が自動出力）
- 1ページだけの一覧にdisabledな前後buttonや「1ページのみ」を表示する
- 操作列を全画面一律110pxに固定し、右端の操作を切れたままにする
- ソート対応カラムの key とコントローラーの allowed 名が不一致
