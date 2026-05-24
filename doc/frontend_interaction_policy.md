# フロントエンド操作の方針

このアプリケーションでは、Rails の server-rendered HTML を中心にして、必要な範囲だけブラウザ上の振る舞いを追加する。

優先順位は次の通り。

1. Turbo のみ
2. Stimulus
3. 素の JavaScript

## 1. Turbo のみを優先する

画面遷移、フォーム送信、一覧更新、部分差し替え、非同期更新は、まず Turbo / Turbo Frame / Turbo Stream で実現できるかを検討する。

例:

- フォーム送信後に一覧だけ更新する
- 詳細領域だけ差し替える
- 検索条件に応じて一覧を再描画する
- サーバ側の結果をそのまま HTML として返す

Turbo で完結できる場合は、Stimulus controller や手書き JavaScript を追加しない。

## 2. 小さなブラウザ上の振る舞いは Stimulus に閉じ込める

Turbo だけでは表現しづらい、DOM に密着した小さな振る舞いは Stimulus controller にする。

例:

- 表示列、列幅、並び順などの table preference UI
- Tom Select を使った検索可能な select / tag / autocomplete 入力
- 開閉、ドラッグ、リサイズ
- iframe 内やプレビュー内の補助 UI
- キーボード操作やアクセシビリティ属性の同期

Stimulus controller は、対象 DOM の `data-controller` と `data-*-target` に責務を閉じ込める。`application.js` に直接 `querySelectorAll` とイベント登録を増やさない。

## 3. 素の JavaScript は最後の手段にする

既存の `setupXxx()` 型の関数はすぐに全削除しない。ただし、新しい UI では同じ形式を増やさない。

既存処理を触る場合は、可能な範囲で Stimulus controller へ移す。

移行時の注意:

- Turbo 再描画後の再初期化は Stimulus の `connect()` に寄せる
- 二重初期化を避ける
- 既存の `turbo:load` / `turbo:render` 依存を少しずつ減らす
- gem が controller を提供している場合は gem 側 controller を優先する

## 今回の gem 連携での位置づけ

### tree_view-rails

Rails helper / HTML 生成が中心。可能な限り Turbo による差し替えで扱う。

### rails_table_preferences

表示列、列幅、プリセット、並び替えなどブラウザ上の小さな状態管理が必要なため、gem 提供の Stimulus controller を使う。

ただし、Markdown preview table は別扱いです。current `main` では Docusaurus が生成した HTML table を Rails helper 経由で `rails_table_preferences` に接続しておらず、`app/frontend/controllers/preview_table_resizer_controller.js` が app 側 fallback path として表幅、列幅、ヘッダー固定、先頭列固定、localStorage ベースの状態保存を担っています。

現時点の責務分担は次の通りです。

- Rails の通常一覧 table: `rails_table_preferences`
- Markdown preview table: `preview_table_resizer_controller.js` による app 側 preview tool

`docs-portal#475` は Markdown table を今後どこまで `rails_table_preferences` に寄せるかの親論点で、まだ `needs-human` です。`docs-portal#542` と PR `#550` は fallback path の stable key を先に整えた slice、`docs-portal#547` はその挙動を回帰確認で守る quality queue として扱います。

### rails_fields_kit

通常の form helper は Ruby / HTML として使う。検索可能な select、tag、autocomplete など Tom Select と相性がよい入力補助は、rails-fields-kit の helper が出力する `data-controller="rails-fields-kit--tom-select"` と gem 提供の Stimulus controller に寄せる。

Tom Select 自体は避けない。避けるのは、アプリ側で `new TomSelect(...)` を直接呼ぶ手書き初期化を増やすこと。

## Vite との関係

Vite は JavaScript / CSS / npm package を読み込むための入口であり、Stimulus と競合しない。

このアプリでは Vite entrypoint で Stimulus application を起動し、gem またはアプリ側の controller を登録する。

```js
import { Application } from "@hotwired/stimulus"

const application = Application.start()
application.register("example", ExampleController)
```

Vite は読み込みとビルド、Stimulus は DOM 上の振る舞い、Turbo は Rails 画面更新を担当する。
