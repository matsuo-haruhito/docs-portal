# UI設計パターン

inclusion: always

## 設計原則

- UIコンポーネントは再利用可能な単位に分割する（ViewComponent）
- 同じHTML構造を複数のSlimテンプレートにコピペしない
- 一覧画面は rtp + rfk の標準パターンに従う
- 画面に直接表示するのは「値」だけ。補足説明はツールチップに逃がす
- 状態変更は許可された操作のみ表示する（任意選択ドロップダウンにしない）
- 管理画面は情報密度高め — テーブル+フィルタ+エクスポートのフル装備
- 公開側は最小限の導線で目的の文書に辿り着ける
- 画面を豪華にするのではなく、重要なものだけを強くし、それ以外を静かにする

## Visual designとCSS責務

- 通常情報はNeutral、操作はAction Blue、ブランドは限定的にOrange、警告・危険はsemantic colorで表す
- tokenの正本は `docs/specs/閲覧画面とUI.md` の「Visual design system」とし、`--ui-bg`、`--ui-surface`、`--ui-text`、`--ui-muted`、`--ui-border`、`--ui-action`、`--ui-brand`、semantic color、radius、floating shadowを共通利用する
- Orangeを通常Card、検索領域、generic badge、ID / codeへ使わない。generic badge、role、カテゴリ、filter chipはNeutralとし、意味のある状態だけsemantic modifierを使う
- 通常Cardはwhite surface、neutral border、8px radius、shadowなしを基本とする。shadowはDialog、Dropdown、Popover、Floating panel等だけに使う
- `.admin-main`を巨大な白いCardにせず、neutral page background上へScreen title、Filter toolbar、List meta、Table / 必要なCardを配置する
- `:root`のtokenと最小resetを除き、`header`、`main`、`button`、`input`等のbare element selectorへプロダクト固有の見た目を持たせない
- Shellとcomponentの見た目は`.app-header`、`.user-nav`、`.admin-header`、`.admin-main`、`.page-header`、`.button`、`.form-control`等へscopeする
- component専用CSSをgeneric Bootstrap overrideより優先し、Sidebar toggle、Column Settings、RTP editorを意図せず上書きしない
- bare `input { width: 100% }`を使わず、text系input、select、textareaだけをfull widthにする。PCのsubmit buttonはcontent widthとする
- 管理画面は1440pxを基準にPC表示を検証する。個別の改善指示でモバイル対象外とされた作業へモバイル固有変更を混ぜない

---

## 一覧画面の標準パターン

### 構成

```slim
section
  / ページヘッダー（タイトル + 新規登録ボタン）
  header
    h1 一覧タイトル
    .actions
      = link_to "新規登録", new_xxx_path

  / 検索フィルタカード
  = form_with url: xxx_path, method: :get do |f|
    / rfk_select, rfk_search_field, rfk_combobox 等
    = f.submit "検索"
    = link_to "条件クリア", xxx_path(clear_filters: 1)

  / 列設定（共通Componentがnative detailsで初期closedにする）
  = render ColumnSettingsComponent.new(
    table_key: "xxx.index",
    columns: columns,
    settings: settings,
    title: "一覧の表示設定"
  )

  / テーブル（rtp対応）
  = table_preferences_table_tag(table_key: "xxx.index", columns: columns, settings: settings) do
    thead
      tr
        - columns.each do |col|
          th data-rails-table-preferences-column-key=col[:key] = col[:label]
    tbody
      - @records.each do |record|
        tr
          - columns.each do |col|
            td data-rails-table-preferences-column-key=col[:key]
              / セル描画

  / フッター（2ページ以上の場合だけページネーション。エクスポートは独立）
  - if pagy.pages > 1
    nav aria-label="一覧ページ"
      / ページネーション
  .actions
    = link_to "CSV出力", xxx_path(format: :csv)
```

### ルール

- 全一覧画面に rtp（rails_table_preferences）を適用する
- 列設定は `ColumnSettingsComponent` で描画し、初期状態は閉じる。画面へ `table_preferences_editor` を直接常時展開しない
- 列設定ボタンはPrimaryではなくneutral outline / ghostのUtilityとして表示し、件数と同じList meta領域へ置く
- テーブルのカラム定義はモデルの全項目を網羅する（ユーザーが列設定で任意に表示ON/OFF）
- 初期表示は `default_visible: true` で主要5〜8列に絞る
- 検索パラメータは rparam でセッション記憶する
- CSV エクスポートは検索・ソート結果を反映する
- ページネーションは pagy で統一し、2ページ以上の場合だけtableの後に表示する。1ページ時はdisabledな前後操作や「1ページのみ」を表示しない
- CSV / Excel等のエクスポートはページャーと独立して表示する
- ソートはcontroller側で固定の `.order(...)` を指定する（`sortable: true` は現行版では使用しない）

### 列定義の方針

- View側ではテーブルが持つ**ほぼ全てのカラム**を列定義（columns配列）に含める
- デフォルトで表示するカラムと非表示にするカラムを `default_visible` で制御する
- ユーザーは列設定エディターから「表示したい列」をONにして自分好みにカスタマイズできる
- 新しい画面を作るとき: まず全カラムをcolumnsに列挙し、主要5〜8列を`default_visible: true`（デフォルト）、残りを`default_visible: false`にする

### 短文カラムの default_width 設定

`table-layout: fixed` ではカラム幅が均等分配されるため、短文しか表示しないカラムには `default_width` を指定して幅を絞る。主要テキスト列（タイトル、文書名等）には指定せず、残り幅を自然に吸収させる。

#### 幅の計算式

中身よりヘッダー文字列の方が幅を取る場合:

```
default_width = 25 + 15 × 文字数
```

- 文字数にはフィルタアイコン（▾）も1文字として数える
- 例: 「版」(1文字) → 25+15×1 = 40
- 例: 「状態▾」(3文字) → 25+15×3 = 70
- 例: 「公開日」(3文字) → 25+15×3 = 70 → 日付幅の105を採用

#### カラム種別ごとの標準幅

| カラム種別 | default_width | 例 |
|---|---|---|
| 版（1桁数値） | 40 | 1, 2 |
| 表示順・件数 | 70 | 10, 3 |
| 状態/種別（バッジ） | 80 | 下書き, 公開中 |
| カテゴリ（バッジ短文） | 85 | 仕様書, 手順書 |
| 日付（YYYY-MM-DD） | 105 | 2026-08-01 |
| 操作（Bootstrap Icons） | 実操作数に応じる | `bi-eye`, `bi-pencil`, `bi-trash` |
| 日時（短縮表示） | 130 | 08/01 15:30 |

#### ルール

- 中身が短い（数字1〜2桁、バッジ1語、日付10文字）カラムは必ず `default_width` を指定する
- 操作列は110pxへ一律固定せず、表示する許可済み操作の数、ラベル、保存済みRTP幅に合わせる。1440pxで右端の操作が切れないことを確認する
- 操作列のicon-only buttonにはBootstrap Iconsを使い、対象を特定できる`aria-label`と`title`を付ける
- 長いテキストを表示するカラム（タイトル、文書名、案件名、備考等）には指定しない
- ユーザーが列設定エディターで幅を保存済みの場合はそちらが優先される
- ヘッダー文字列が長いカラムは計算式に従い幅を広げる

### テーブルセルの省略表示

一覧テーブルのセルは、デフォルトで**改行させず、あふれたテキストを `...` で省略する**。

- rtp のカラム定義で `overflow: :ellipsis` がデフォルト適用される
- テーブルには CSS で `table-layout: fixed` を適用する
- 折り返しが必要なカラム（備考等）は明示的に `overflow: :wrap` を指定する

### NGパターン

- rtp を使わず手書きで `<table>` を描画する
- th 内に手動でソートリンクを書く（controller側の固定orderで対応する）
- セルのテキストが改行されてテーブルの行高がバラバラになる

---

## 詳細画面の標準パターン

### 構成

```slim
section
  header
    h1 リソース名 + 識別子
    .actions
      / 編集、削除、状態変更ボタン

  / 属性表示
  dl
    div
      dt ラベル
      dd 値

  / 関連情報（テーブルまたはパネル）
  section
    h2 関連セクション
    table
```

### 詳細画面の情報設計

- 文書詳細: 基本情報 + 版一覧 + 権限サマリ + ツリー位置 + コメント/Q&A
- 案件詳細: 案件情報 + 所属文書一覧 + メンバー + 外部連携状態
- Import 結果: 実行概要 + 処理対象一覧（成功/失敗/スキップ）

### ルール

- 詳細画面には現在状態から実行可能な「次の操作」を表示する
- 関連レコードへのリンクだけでなく、要約情報をインラインで見せる
- Turbo Frame で展開/折りたたみ（初回展開時にfetch、読み取り専用）

---

## フォーム画面の標準パターン

### 構成

```slim
section
  = form_with model: @record do |f|
    .form-group
      = f.label :field
      = f.rfk_select :field, collection: ...

    .actions
      = f.submit "保存"
```

### ルール

- フォームフィールドには rfk_select / rfk_combobox を使う
- バリデーションエラーはフォーム上部にサマリ + 各フィールド直下に表示
- `required: true` を付けたフィールドのラベルには必須マークを付与する

### 必須項目の表示ルール

ラベルの横に `[※必須]` を赤字・小さめフォントで表示する。

```slim
= f.label :name, class: "form-label"
  | 文書タイトル
  span.required-mark ※必須
```

```css
.required-mark {
  color: #c42b3a;
  font-size: 0.7rem;
  font-weight: 600;
  margin-left: 0.3rem;
  vertical-align: middle;
}
```

#### ルール

- `required` 属性を持つフィールドのラベルには必ず `.required-mark` を付与する
- 色だけに依存しない（テキスト「※必須」で意味を伝える）
- 新規画面を作るとき: `required: true` を付けたフィールドは同時にラベルに `.required-mark` を追加する
- 既存画面の改修時に `required` フィールドに `.required-mark` がなければ追加する

---

## ViewComponent 活用方針

同じ構造が3箇所以上に出現する場合はViewComponentに切り出す。

### 切り出し対象の候補

| Component | 責務 |
|---|---|
| PageHeaderComponent | 画面タイトル、サブタイトル、アクションボタン |
| FilterCardComponent | 検索カードの外枠・折返し |
| ListFooterComponent | ページネーション、CSV、Excelボタン |
| EmptyStateComponent | データ0件時の案内（説明+推奨操作） |
| ColumnSettingsComponent | 列設定ボタン・table_preferences_editor |
| BreadcrumbComponent | パンくずナビゲーション |
| StatusBadgeComponent | 状態バッジ（色+テキスト） |
| SectionNavComponent | セクション内ナビゲーション |
| InfoTooltipComponent | 項目名の補助説明ツールチップ |
| HelpTooltipComponent | 操作ガイド用ツールチップ |

### ルール

- Component内部に業務ロジックを入れない（表示のみ）
- 権限による表示制御はComponentに渡す値で外から制御する
- 画面ごとにCSV/Excelボタンの文言や配置を揺らさない

---

## フローティングパネル（ドロップダウン入力）

テーブル内やパネル内のボタンから展開する入力パネル・メニューは、親要素の `overflow` や `z-index` に隠れてはならない。

### 必須ルール

- `position: absolute` + `z-index` で親要素内に配置する方式は**禁止**（overflow: hidden/auto で切れるため）
- `position: fixed` + Stimulus controller で画面固定座標に表示する
- パネル内のフォームフィールドはDOMツリー上フォーム内に残し、送信に含まれるようにする
- Escapeキーで閉じる、外側クリックで閉じる
- 閉じたときにトリガーボタンへフォーカスを戻す

### 実装パターン

```slim
/ floating-panel controller を使う
.d-inline-block data-controller="floating-panel"
  button.btn.btn-sm type="button" data-floating-panel-target="trigger" data-action="click->floating-panel#toggle"
    | ラベル
  .floating-panel data-floating-panel-target="panel"
    / フォームフィールド（select, input等）
```

### CSS

```css
.floating-panel {
  position: fixed;
  z-index: 1070;
  display: none;
  min-width: 20rem;
  padding: 0.75rem;
  border: 1px solid #dee2e6;
  border-radius: 0.45rem;
  background: #fff;
  box-shadow: 0 0.5rem 1.5rem rgba(0, 0, 0, 0.15);
}
.floating-panel.is-open { display: block; }
```

### 例外: ナビバーのドロップダウン

ページ最上部のナビバー内のドロップダウンは `position: absolute` をそのまま使ってよい。ナビバーは overflow コンテナの中に入らないため。

### NGパターン

- `z-index` を上げるだけで解決しようとする（スタッキングコンテキスト内では無効）
- パネルを `document.body` に移動してフォーム送信から外してしまう

---

## ツールチップ（情報設計の中核）

ツールチップは「操作説明が要らないUI」を実現するための主要手段。

### 設計原則

- 画面に直接表示するのは「値」だけ。「値の意味」「操作の補足」はツールチップに逃がす
- 新機能・新画面を実装する際は「初見で迷いそうな箇所」を洗い出し、積極的に付与する
- 説明文は1〜2文で簡潔にする
- `tabindex=0` + `aria-label` でアクセシビリティ対応
- ホバーとフォーカスの両方で表示する

### 情報ツールチップ（`info_tooltip`）

項目名・見出し・ラベルの補助説明に使う。

```slim
.heading-with-help
  h2 見出しテキスト
  = info_tooltip "見出し", "この機能の補足説明"
```

用途例:
- 一覧画面の見出し横: その画面で何が確認でき、何ができるか
- テーブルヘッダー: ステータスの意味、カラムの算出ロジック
- フォームラベル: 入力値の形式・制約・影響範囲

### ヘルプツールチップ（`help_tooltip`）

操作ガイド用。ボタンやアクションの近くに配置。

用途例:
- 「次に何をすればよいか」の案内
- 条件付き操作の前提説明（「○○の場合のみ実行できます」）
- 一括操作の影響範囲の注意喚起

### docs-portal で適用すべき箇所

- import 画面: dry-run の意味、各ステータスの説明
- 文書権限設定: ロールの違い、権限の影響範囲
- 外部連携設定: Webhook の署名方式、再送の仕組み
- 文書セット: 「固定版」と「最新版を使う」の違い
- 監査ログ: 各イベント種別の意味
- 外部フォルダ同期: 安全判定の意味、競合警告の見方
- 文書版 rollback: 影響範囲（公開状態がどう変わるか）
- 確認依頼: 承認/差し戻しの影響範囲
- 同意管理: 同意スコープの違い、必須タイミングの意味

### 情報の性質による使い分け

| 情報の性質 | 表示方法 |
|---|---|
| 用語の短い補足、項目の意味 | 情報ツールチップ（info_tooltip） |
| ボタン操作の結果説明 | ヘルプツールチップ（help_tooltip） |
| 2〜5行の操作説明 | インラインヘルプまたはDisclosure |
| 不可逆操作の最終確認 | レビューページまたは確認画面 |
| 初回だけ必要な案内 | Dismissible callout |

### ルール

- 機械的に全項目へ付けるのではなく、「初見で迷う箇所」「誤操作が起きやすい箇所」に集中させる
- ただし「付けすぎを恐れて付けない」より「迷うかも？と思ったら付ける」を優先する
- ボタンの操作説明には help_tooltip を使い、項目名の補足には info_tooltip を使う

---

## エラー表示の共通化

### 必須要件

- ページ上部にエラー件数と一覧を表示する
- 各エラーから対象入力欄へのリンク（クリックでフォーカス移動）
- 項目直下にも具体的な修正方法を表示
- 入力値と選択状態を保持する（エラー後にデータが消えない）
- 最初のエラーサマリーへフォーカス移動
- `role=alert` の乱用を避ける（フラッシュメッセージのみ）

### Import/Sync 結果のエラー表示

- 成功/失敗/スキップの件数サマリを先頭に表示する
- 失敗行は理由付きのテーブルで一覧表示する
- 部分成功は「○件成功、×件失敗」を明示する

---

## フラッシュメッセージ

フラッシュメッセージは単なる「完了通知」ではなく、操作の結果と次のステップを伝えるガイドとして活用する。

### ルール

- notice は成功 + 次のアクションへの誘導
- alert は失敗 + 原因 + 解消方法
- 文言は具体的に（「処理が完了しました」のような汎用文言を避ける）

### 良い例

```ruby
# notice
"文書「#{document.title}」を公開しました。権限を設定してください。"
"Git同期が完了しました。3件の文書が更新されました。"

# alert
"文書の保存に失敗しました。タイトルは必須です。"
"外部フォルダ同期に失敗しました。OAuth接続が期限切れです。再接続してください。"
```

---

## ステータス表示

ステータスはバッジ（StatusBadgeComponent）で統一する。色とテキストの両方で状態を伝える（色だけに依存しない）。

### バッジの色割り当て方針

| 状態カテゴリ | 色 | 例 |
|---|---|---|
| 公開中・完了・成功 | 緑系 | published, completed, success |
| 下書き・準備中 | 灰色系 | draft, pending |
| 処理中・同期中 | 青系 | running, syncing |
| 警告・要確認 | 黄色系 | warning, needs_review |
| 失敗・エラー | 赤系 | failed, error |
| アーカイブ・無効 | 薄灰色系 | archived, disabled |

### ルール

- 同じステータス値には全画面で同じ色を使う
- バッジにはツールチップでステータスの意味を補足する（StatusBadgeComponent が対応）
- 色覚多様性に配慮し、色だけで意味を伝えない（テキストラベル必須）

---

## 状態遷移は許可された操作のみ表示

文書状態変更を任意選択のドロップダウンにしない。

### ルール

- モデルに許可遷移を定義する
- 画面には現在状態から実行可能な業務操作だけをボタンとして表示する
- アーカイブ・取消は理由確認付きで操作結果を具体的に表示する
- version immutability: 一度 publish した版は変更不可（修正は新版で行う）

---

## Import / Sync フローのUI設計

Import・同期系の操作は段階的フローで安全に実行する。

### 共通フロー

```
dry-run（検証） → レビュー（確認） → 実行（適用）
```

### 表示すべき情報

- dry-run 結果: 対象件数、変更内容のプレビュー、警告・エラー
- レビュー画面: 変更前/後の差分、影響範囲の明示
- 実行結果: 成功/失敗/スキップの内訳、失敗理由の詳細

### 外部フォルダ同期のUI

- 安全判定（conflict_warnings）を色分けバッジで表示する
- 競合がある場合は「強制適用」ボタンを明示的に分離する
- 承認済み/未承認の状態と承認者を表示する

### ルール

- dry-run の段階で問題を発見・解消できるUIにする
- 「確認ダイアログだけで不可逆操作を実行」しない
- 部分成功時は工程別に結果を表示する

---

## 文書ツリー表示

文書の階層構造表示には tree_view-rails を使用する。

### ルール

- 自前のネスト表示を実装しない（tree_view-rails に統一）
- 展開/折りたたみは Turbo Frame と組み合わせて部分読み込みにする
- 現在表示中の文書ノードをハイライトする
- ツリーの開閉状態はセッションで保持する

---

## UIコンポーネントの使い分け

| コンポーネント | 使う場面 | 使わない場面 |
|---|---|---|
| タブ | 同一業務対象の並列・独立した情報領域の切替 | 手順や前後関係を隠す |
| セグメントボタン | 同じデータの表示形式だけの切替 | データの状態が変わる操作 |
| アコーディオン | 補足情報、必要時だけ確認する詳細 | 主要な状態情報を隠す |
| モーダル | 文脈を保った短い選択、取消可能な小規模入力 | 多数項目の比較、重要な不可逆操作のレビュー |
| 確認画面 | 不可逆操作（公開、アーカイブ、import適用）のレビュー | 単なる保存、軽微な操作 |

### 共通ルール

- タブは `role=tablist/tab/tabpanel`、矢印キー操作、フォーカス移動を含めて実装する
- view queryでactive panelだけをSSRするtabは、各tabの`aria-controls`を対応する固定panel IDへ向ける。inactive tabがactive panel IDを参照してはならない
- 文書権限は`document-permissions-assignments-panel`と`document-permissions-overview-panel`を固定IDとして使う
- アコーディオンは `aria-expanded` で開閉状態を通知する
- モーダル表示中はフォーカスを内部に閉じ、閉じた後は起動元へ戻す
- 状態、エラー、成功は色だけで表現せず、テキストと支援技術向け通知を付ける

---

## 非同期処理・二重実行防止の共通UI

Import、Build、外部同期など非同期処理では以下を共通化する。

- 実行開始後にボタンを無効化し「処理中」と対象を表示する
- 重複作成を防止する（同一 source の二重 sync 起動等）
- 部分成功時は工程別に結果を表示する（例：3件成功、1件失敗 [詳細]）
- 長時間処理は進捗ステータスを Turbo Stream で更新する

---

## Bootstrap Icons の活用

Bootstrap Icons を積極的に活用し、テキストのみのUIからアイコン付きの視認性の高いUIへ統一する。

### 必須適用箇所

| 箇所 | アイコン例 |
|------|-----------|
| サイドバーのナビゲーション項目 | `bi-file-earmark-text`, `bi-folder2` 等 |
| 新規作成ボタン | `bi-plus-lg` |
| CSV エクスポートボタン | `bi-filetype-csv` |
| テーブル行アクション（詳細/編集/削除） | `bi-eye`, `bi-pencil`, `bi-trash` |
| 列設定ボタン | `bi-gear` |
| EmptyState | `bi-inbox` |
| 検索クリアボタン | `bi-x-lg` |
| 文書ツリーの展開/折りたたみ | `bi-chevron-right` |
| 外部連携状態 | `bi-cloud-check`, `bi-cloud-slash` |
| ダウンロード | `bi-download` |

### 基本記法

```slim
/ Slim テンプレートでの記法
i.bi.bi-plus-lg.me-1
i class="bi #{item[:icon]}" aria-hidden="true"
```

- `<i>` タグに `.bi` + `.bi-{icon-name}` を付与する
- テキストラベルと併用する場合は `.me-1` or `.me-2` で間隔を取る
- 装飾目的のアイコンには `aria-hidden="true"` を付与する
- アイコンのみのボタンには `aria-label` で操作内容を伝える

### NGパターン

- Unicode記号（`▼`, `▶`, `⚙`）をアイコン代わりに使う
- アイコンのみのボタンに `aria-label` や `title` を付けない
- 同じ操作に画面ごとに異なるアイコンを使う

---

## Turbo Frames / Streams

- 一覧のフィルタ送信: Turbo Frame で部分更新
- インライン操作: Turbo Stream で行を差し替え
- タブ内コンテンツ: Turbo Frame で遅延読み込み
- ツリーノード展開: Turbo Frame で子ノードを部分読み込み
- Import/Sync 進捗: Turbo Stream でステータス更新

---

## 戻り先の保持

機能Aから機能Bへ遷移した後、Bの一覧ではなく開始元の業務文脈へ戻す。

### 適用例

- 文書一覧 → 権限設定 → 保存後は文書一覧へ戻る
- 確認依頼一覧 → 文書詳細確認 → 「依頼に戻る」で同じ確認依頼へ戻る
- 文書セット編集 → 文書選択 → 保存後はセット編集へ戻る

### 実装

- `return_to` パラメータまたはセッションで戻り先を保持する
- 保存後の redirect 先に戻り先を反映する

---

## レスポンシブ対応

- テーブルは横スクロール対応のラッパーで囲む
- モバイルでは操作ボタンを縦積み or ドロップダウンに折り返す
- 公開側（external user向け）はモバイルでの閲覧を重視する
- 管理画面（admin）はデスクトップ優先だが、テーブル横スクロールは必須

---

## アクセシビリティ

- スキップリンクでメインコンテンツへ遷移可能にする
- `role="alert"` はフラッシュメッセージのみ
- テーブルに `caption` を付与
- ナビゲーションに `aria-label` を付与
- フォーカス管理を適切に行う
- ツールチップは `tabindex=0` でキーボードアクセス可能にする
- アイコンのみのボタンには `aria-label` を付与する
- 色だけで情報を伝えない（テキストラベルを併用する）

---

## 日本語表示の徹底

画面上に英語がそのまま表示されることがないようにする。エラーメッセージ、enumの選択肢、カラム名、ボタンラベル等すべて日本語で表示すること。

### ルール

- モデルの属性名は `config/locales/ja.yml` の `activerecord.attributes` で日本語化する
- enumの選択肢は日本語化する
- 新しいモデルやカラムを追加したら、必ず同時にロケールファイルも更新する
- 外部連携のステータス（success, failed 等）も日本語ラベルで表示する

---

## 公開側（external user向け）の設計方針

### 原則

- 最小限の導線で目的の文書に辿り着ける
- 検索・フィルタは直感的に操作できる
- ダウンロード操作は1クリックで完了する
- 権限がない文書は「存在しない」のではなく「アクセス申請」導線を出す

### 文書閲覧画面

- 文書ツリーで構造を把握し、目的のノードへ到達する
- 版の切り替えはタブまたはセレクトで行う
- 添付ファイルの一覧とダウンロードは文書詳細内に配置する
- プレビュー（HTML）は iframe で表示する

### アクセス申請

- 権限がない文書/案件への遷移時に「アクセス申請」ボタンを表示する
- 申請後は「承認待ち」状態を利用者に明示する
