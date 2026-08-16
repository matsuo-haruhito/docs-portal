# 画面仕様ドキュメント自動生成

inclusion: always

---

## 正本の構造

```
script/screenshot_scenarios.ts    ← 明示的シナリオ（正本）
capture_screenshots.ts            ← routes.rb から自動シナリオ生成 + 撮影
    ↓ 実行結果
docs/screenshots/
├── scenario-manifest.json        ← 全シナリオ定義（explicit + auto）
├── coverage-ledger.json          ← 各シナリオの撮影結果
├── metadata.json                 ← 撮影メタデータ
└── *.png                         ← スクリーンショット画像
    ↓
script/generate_screen_docs.ts    ← manifest + coverage から Markdown 生成
    ↓
docs/screen_guide.md              ← 自動生成（直接編集禁止）
```

---

## 運用ルール

### docs/screen_guide.md は直接編集しない

`screen_guide.md` はテスト可能な仕様を人間が読める形に投影したもの。
正本はシナリオ定義と撮影結果であり、`bin/all_test` 成功時に自動再生成される。

### 新機能・新画面を追加した場合

1. Controller + View + routes.rb を実装する
2. routes.rb に admin namespace のルーティングがあれば `capture_screenshots.ts` が自動的に発見し、ベースラインシナリオを生成する（Level 1: AUTO）
3. 画面の用途・操作が明確になったら `script/screenshot_scenarios.ts` に明示的シナリオを追加する（Level 2: SPECIFIED）
   - `screenName`: 日本語の画面名
   - `userStory`: 誰が何のために使う画面か
   - `expectedBehavior`: この画面でできること（業務レベル）
   - `documentRole`: 省略可。デフォルト推論（stateKind=default→primary, else→supplemental）

### 既存画面の振る舞いを変更した場合

対応するシナリオの `userStory` / `expectedBehavior` / `actions` に変更が必要ないか確認する。

### シナリオの documentRole

| stateKind | デフォルト推論 | screen_guide での扱い |
|-----------|---------------|---------------------|
| default | primary | 独立した画面として掲載 |
| empty / error / mobile / restricted / processing | supplemental | 同じ画面の補足状態として親グループ内に掲載 |
| （任意） | exclude（明示指定） | テストのみ。ドキュメントには出さない |

---

## シナリオの書き方

### id 命名規則

```
{resource-key}.{action}.{role}.{viewport}
```

- `resource-key`: ハイフン区切り（例: `admin-documents`, `admin-git-import-sources`）
- `action`: `index` / `new` / `show` / `edit` / カスタム名
- `role`: `guest` / `admin` / `external` / `company_master_admin`
- `viewport`: `desktop`（モバイル対応時は `mobile`）

### outputName 命名規則

```
{resource-key}-{action}[-{state}]
```

- ハイフン区切り、小文字英数字のみ
- 状態バリエーションは末尾に `-empty`, `-error`, `-mobile` 等を付ける

### expectedBehavior の粒度

- 1行1操作/1確認で書く
- 「〜の確認」「〜の変更」「〜へのフィルタ」のように動詞で終える
- 画面で実際にできる業務操作を列挙する（UI部品の説明ではなく業務目的）

### deferred の使い分け

| 使う場面 | reason の例 | resumeCondition の例 |
|---------|-------------|---------------------|
| 外部利用者の撮影環境が未整備 | 撮影環境に外部利用者の認証情報がない | SCREENSHOT_EXTERNAL_EMAIL を環境変数に登録する |
| 動的IDが必要 | 動的な案件codeが必要 | seed案件を特定してURLを生成する |
| 非同期処理の固定が必要 | 処理中状態を決定的に保持できない | pause adapterを用意する |

---

## generate_screen_docs.ts の設計方針

- **業務知識を持たない**: screenName, userStory, expectedBehavior はすべて scenario-manifest.json から読む
- **SCREEN_ORDER**: 章立て（公開側/管理画面/システム管理）と表示順のみ保持。画面の意味は知らない
- **新画面は自動的に表示される**: SCREEN_ORDER に含まれない画面も章末尾に追加される

---

## docs-portal 固有の方針

### 自動発見の対象

`capture_screenshots.ts` は `admin` namespace 配下のリソースだけを自動発見する。
公開側（external user向け）の画面は動的IDや権限が複雑なため、明示的シナリオで管理する。

### 撮影セレクタ

- admin 画面の期待状態: `.admin-header`（管理画面ヘッダー）
- 公開側の期待状態: `main` または `[data-docs-sidebar]`（文書ツリー）
- ゲスト画面: `form`（ログインフォーム）

### ロール定義

| role | 対象 |
|------|------|
| `guest` | 未ログイン利用者 |
| `admin` | internal admin / staff（全管理機能アクセス可） |
| `external` | 許可された案件・文書のみ閲覧 |
| `company_master_admin` | 自社の会社・ユーザー管理のみ |

---

## やらないこと

- 要件からシナリオへの機械的な ref リンク管理
- 全シナリオの一斉精緻化（育てる運用）
- 公開側全画面の自動発見（権限・動的IDの解決コストが高い）
