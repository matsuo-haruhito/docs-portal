# UI設計パターン

inclusion: always

## 設計原則

- UIコンポーネントは再利用可能な単位に分割する（ViewComponent）
- 同じHTML構造を複数のSlimテンプレートにコピペしない
- 一覧画面は rtp + rfk の標準パターンに従う
- 画面に直接表示するのは「値」だけ。補足説明はツールチップに逃がす
- 状態変更は許可された操作のみ表示する（任意選択ドロップダウンにしない）

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

  / 列設定エディター
  = table_preferences_editor(table_key: "xxx.index", columns: columns)

  / テーブル（rtp対応）
  = table_preferences_table_tag(table_key: "xxx.index", columns: columns, settings: ...) do
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

  / フッター（ページネーション + エクスポート）
  nav
    / ページネーション
    .actions
      = link_to "CSV出力", xxx_path(format: :csv)
```

### ルール

- 全一覧画面に rtp（rails_table_preferences）を適用する
- テーブルのカラム定義はモデルの全項目を網羅する（ユーザーが列設定で任意に表示ON/OFF）
- 初期表示は `default_visible: true` で主要5〜8列に絞る
- 検索パラメータは rparam でセッション記憶する
- CSV エクスポートは検索・ソート結果を反映する
- ページネーションは pagy で統一する
- ソートはヘッダークリックで rtp Stimulus controller が処理する（手動ソートリンク不要）

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

### 例外: ナビバーのドロップダウン

ページ最上部のナビバー内のドロップダウンは `position: absolute` をそのまま使ってよい。ナビバーは overflow コンテナの中に入らないため。

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
- テーブルヘッダー: 数値カラムの算出ロジック、ステータスの意味
- フォームラベル: 入力値の形式・制約・影響範囲

### ヘルプツールチップ（`help_tooltip`）

操作ガイド用。ボタンやアクションの近くに配置。

用途例:
- 「次に何をすればよいか」の案内
- 条件付き操作の前提説明（「○○の場合のみ実行できます」）
- 一括操作の影響範囲の注意喚起

### 適用すべき箇所

- import 画面: dry-run の意味、各ステータスの説明
- 文書権限設定: ロールの違い、権限の影響範囲
- 外部連携設定: Webhook の署名方式、再送の仕組み
- 文書セット: 「固定版」と「最新版を使う」の違い
- 監査ログ: 各イベント種別の意味

### ルール

- 機械的に全項目へ付けるのではなく、「初見で迷う箇所」「誤操作が起きやすい箇所」に集中させる
- ただし「付けすぎを恐れて付けない」より「迷うかも？と思ったら付ける」を優先する

---

## フラッシュメッセージ

フラッシュメッセージは単なる「完了通知」ではなく、操作の結果と次のステップを伝えるガイドとして活用する。

### ルール

- notice は成功 + 次のアクションへの誘導
- alert は失敗 + 原因 + 解消方法
- 文言は具体的に（「処理が完了しました」のような汎用文言を避ける）

---

## ステータス表示

ステータスはバッジで統一する。色とテキストの両方で状態を伝える（色だけに依存しない）。

---

## Turbo Frames / Streams

- 一覧のフィルタ送信: Turbo Frame で部分更新
- インライン操作: Turbo Stream で行を差し替え
- タブ内コンテンツ: Turbo Frame で遅延読み込み

---

## レスポンシブ対応

- テーブルは横スクロール対応のラッパーで囲む
- モバイルでは操作ボタンを縦積み or ドロップダウンに折り返す

---

## アクセシビリティ

- スキップリンクでメインコンテンツへ遷移可能にする
- `role="alert"` はフラッシュメッセージのみ
- テーブルに `caption` を付与
- ナビゲーションに `aria-label` を付与
- フォーカス管理を適切に行う

---

## 日本語表示の徹底

画面上に英語がそのまま表示されることがないようにする。エラーメッセージ、enumの選択肢、カラム名、ボタンラベル等すべて日本語で表示すること。

### ルール

- モデルの属性名は `config/locales/ja.yml` の `activerecord.attributes` で日本語化する
- enumの選択肢は日本語化する
- 新しいモデルやカラムを追加したら、必ず同時にロケールファイルも更新する
