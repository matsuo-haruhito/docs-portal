# コーディングルール

inclusion: always

## 基本方針

- **Rails Way を尊重する**: Convention over Configuration を最大限活用し、Railsの規約から逸脱しない
- **DRY**: 同じロジックを2箇所以上に書かない。Concern、Helper、専用クラスで適切に共通化する
- **EditorConfig 準拠**: `.editorconfig` で定義されたフォーマット設定（インデント、改行コード、末尾空白等）に従う

#[[file:.editorconfig]]

---

## ディレクトリ構成

```text
app/
├── controllers/
│   ├── concerns/        # Controller concerns
│   ├── admin/           # 管理画面 controllers
│   └── api/             # API controllers
├── models/
│   └── concerns/        # Model concerns
├── services/            # 原則増やさない（責務名付きディレクトリを優先）
├── importers/           # Import 処理
├── renderers/           # Docusaurus HTML 変換・配信補助
├── previews/            # dry-run / 変更前 preview
├── checks/              # 診断・品質確認
├── builders/            # 組み立て処理
├── queries/             # Query Objects（複雑な検索・集計）
├── helpers/             # View helpers
├── views/               # Slim テンプレート
└── frontend/            # Vite/Stimulus TypeScript
    ├── controllers/     # Stimulus controllers
    └── entrypoints/     # Vite entrypoints
```

### 専用クラスの配置

- import 処理は `app/importers/` に置く（例: `DocumentImporter`）
- Docusaurus HTML の変換・配信補助は `app/renderers/` に置く（例: `DocusaurusSiteRenderer`）
- dry-run や変更前 preview の組み立ては `app/previews/` に置く（例: `DocumentBulkEdit::ChangeNormalizer`）
- 診断・品質確認の check 群は `app/checks/` に置く（例: `ApplicationConfiguration::EnvironmentChecks`）
- import 配下の走査・展開・manifest 組み立ては `app/importers/<feature>/` に置く（例: `ZipImport::ArchiveExtractor`）
- seed 専用処理は `db/seeds/support/` に置く（例: `SeedSupport::DocusaurusBuilder`）
- `app/services` は原則として増やさない
- ただし、Rails 標準の置き場や責務名付きディレクトリで表現しづらいものだけ、例外的に利用を検討する

### `app/` 直下を増やす判断基準

- 新しいトップレベルカテゴリは、責務が名前で即説明でき、今後も複数クラスで再利用される見込みがある時だけ追加する
- 目安: 同種のクラスが 3 個以上ある、または近いうちに増える見込みがある場合に検討
- 単発の helper や一時的な分解なら、既存カテゴリ配下へ置くか、service を薄くして近い責務へ寄せる
- `app/services/<use_case>/` は第一選択にしない（orchestration と判定・整形・走査が同じ箱へ戻りやすいため）
- 既存の `app/previews/`, `app/checks/`, `app/importers/`, `app/builders/` で表現できるならそちらを優先
- service を thin にした後、責務名が明確になったクラスは `app/services` から移す

---

## Concern の活用

ActiveSupport::Concern を積極的に使い、モデルやコントローラの肥大化を防ぐ。

### ルール

- 2つ以上のモデル/コントローラで共有するロジックはConcernに抽出する
- Concernは単一責務にする
- Concernの命名は形容詞/動詞-able パターンを優先（`Searchable`, `Exportable`）

### 推奨パターン: 検索Concern

```ruby
module Searchable
  extend ActiveSupport::Concern

  included do
    # 日付の範囲検索
    scope :from_to_date_search, ->(attribute, from, to) {
      result = self
      result = result.where("#{table_name}.#{attribute} >= ?", from.to_date) if from.present?
      result = result.where("#{table_name}.#{attribute} < ?", to.to_date + 1) if to.present?
      result
    }

    # 曖昧検索（ILIKE、スペース区切りAND検索）
    scope :like_search, ->(attributes, text) {
      return all if text.blank?
      words = text.split(/[\s　]+/)
      words.inject(all) do |scope, word|
        pattern = "%#{sanitize_sql_like(word)}%"
        conditions = Array(attributes).map { |attr| arel_table[attr].matches(pattern) }
        scope.where(conditions.reduce(:or))
      end
    }
  end
end
```

### 推奨パターン: ソートConcern

```ruby
module Sortable
  extend ActiveSupport::Concern

  included do
    # order_by("name") → 昇順、order_by("-name") → 降順
    scope :order_by, ->(sort, direction = nil) {
      return order(created_at: :desc) if sort.blank?
      key = sort.to_s.delete_prefix("-")
      dir = if direction.present?
              direction.to_s == "desc" ? :desc : :asc
            else
              sort.to_s.start_with?("-") ? :desc : :asc
            end
      order(key => dir)
    }
  end
end
```

### 推奨パターン: Auditable（操作者記録）

```ruby
module Auditable
  extend ActiveSupport::Concern

  included do
    belongs_to :created_by, class_name: "User", optional: true
    belongs_to :updated_by, class_name: "User", optional: true

    before_create :set_created_by
    before_save :set_updated_by
  end

  private

  def set_created_by
    self.created_by ||= Current.user
  end

  def set_updated_by
    self.updated_by = Current.user if Current.user
  end
end
```

---

## Query Object

一覧画面の検索・集計ロジックが複雑な場合はQuery Objectに切り出す。

### ルール

- `app/queries/` に配置する
- `initialize(params)` でパラメータを受け取り、`#relation` でActiveRecord::Relationを返す
- スコープの連結、複雑なJOIN、集計SQLはQuery Object内に閉じ込める

---

## Controller の一覧パターン

### 標準パターン

```ruby
def index
  @records = filtered_records
  respond_to do |format|
    format.html
    format.csv  { send_csv_export(@records) }
  end
end
```

### ルール

- シンプルな検索は Model.search(params) パターン
- 複雑な集計や複数テーブルJOINはQuery Object
- respond_to で html/csv を切り替え
- 検索パラメータは rparam でセッション記憶する

---

## マイグレーション

### テーブル・カラムの日本語コメント必須

マイグレーションファイルでテーブルやカラムを作成・変更する際は、必ず `comment` オプションで日本語の物理名（論理名）を付与すること。

```ruby
create_table :documents, comment: "文書マスタ" do |t|
  t.string :title, null: false, comment: "文書タイトル"
  t.string :slug, null: false, comment: "文書スラッグ（URL用）"
  t.string :status, null: false, default: "draft", comment: "状態（下書き/公開/アーカイブ）"
  t.timestamps
end
```

### ルール

- `create_table` には必ず `comment:` でテーブルの日本語名を指定する
- 全てのカラム（id, timestamps除く）に `comment:` で日本語名を指定する
- コメントは簡潔に（カラムの役割が分かる程度）
- 選択肢がある場合は括弧内に列挙する

---

## 認証・権限

- `current_user` に直接ロール判定を散らさず、`User` モデルに意図の分かる問い合わせメソッドを置く
- `internal`、`admin`、`company_master_admin`、`external` の責務を混同しない
- Project / Document の参照判定は model concern に寄せる
- `DocumentVersion#viewable_by?` や `DocumentFile#downloadable_by?` のような resource 固有判定は model へ直書きする
- controller 側の access gate は `BaseController` に `require_*_access!` として寄せる

---

## public_id

- 外部 URL/API には DB の連番 `id` を直接出さない
- アプリケーション管理テーブルには `public_id` を持たせる
- `public_id` は作成時に自動生成し、原則変更しない
- `public_id` は URL-safe な文字列とし、テーブルごとに prefix を付ける
- `upsert_all` は callback を通さないため、seed や bulk import では `public_id` を明示的に投入する

---

## View

- アプリケーションが所有する HTML テンプレートは Slim（`.html.slim`）で作成する。新規の `.html.erb` は追加しない
- 外部 gem の partial override など、handler 互換性のため ERB が必要な場合だけ `.html.erb` を許可し、理由をコードまたは関連文書で明示する
- テンプレートの拡張子を変更するときは、現行パスを参照する source spec・runbook・代表 smoke の記述も同時に更新する
- 一覧テーブルは原則 `table_tag` を使う
- 編集・削除ボタンは `edit_link_to` `delete_link_to` を優先して使う
- 画面タイトルは `page_title` で設定する
- navbar、flash、エラーメッセージなど、複数画面で使う断片は partial に寄せる

---

## seed / データ投入

- seed は `create!` の逐次投入より `upsert_all` を優先する
- seed 内では enum を文字列のまま渡さず、整数値へ明示変換する
- seed 用の自然キーは CSV 側で安定させる
- seed 用 CSV は `db/seeds/data/` に置く
- seed 補助クラスは `db/seeds/support/` に置く
- seed 用 Docusaurus build は、元ファイルを直接変更せず、一時 workspace で行う

---

## フロントエンド（TypeScript）

### 配置場所

```
app/frontend/
├── entrypoints/          # Viteのエントリポイント
│   └── application.ts
└── controllers/          # Stimulus controllers (.ts)
```

### ルール

- **すべての新規ファイルは TypeScript (.ts) で作成する**
- Stimulusコントローラーは `app/frontend/controllers/` に `.ts` で作成する
- npm パッケージは `npm install` で追加し、普通に `import` する
- レイアウトでは `vite_javascript_tag "application"` を使う
- importmap-rails は既存の互換パスを維持するが、新規追加は Vite 経由を優先する

---

## rails_fields_kit (rfk)

選択系・入力系のフォームフィールドにはrails_fields_kitを活用する。

### ヘルパー選択ガイド

| ヘルパー | 用途 |
|---|---|
| `rfk_select` | 固定選択肢 or マスタ参照（単一選択） |
| `rfk_combobox` | マスタ参照（API検索 + 自由入力可） |
| `rfk_search_field` | フリーワード検索 |
| `rfk_enum_select` | enum属性の選択 |

### ルール

- `collection_select` を使う場面は原則 `rfk_select` に置き換える
- 選択肢が多い（10件以上目安）マスタ参照フィールドは必ず rfk_select を使う
- 「マスタから選ぶ or 自由入力」が両立する場面では rfk_combobox を使う

---

## rails_table_preferences (rtp)

一覧画面のテーブルには rails_table_preferences を適用する。

### ルール

- すべてのindex（一覧）画面にrtpを適用する
- table_key は `"{resource_name}.index"` をデフォルトにする
- `th` と `td` に `data-rails-table-preferences-column-key` を必ず付与する
- sortable カラムにはサーバーサイドソートを連動させる
- エクスポート（CSV）時はrtpの表示設定を反映する

---

## tree_view-rails

親子関係・階層構造の表示には tree_view-rails を活用する。

### ルール

- ツリー構造のデータ表示には必ず tree_view-rails を使う（自前のネスト表示を実装しない）
- 展開/折りたたみはTurbo Frameと組み合わせて部分読み込みにする
- CSSは `stylesheet_link_tag "tree_view"` でレイアウトに読み込む

---

## テスト

### 基本方針

- RSpec を使用
- request spec を優先し、利用者が踏む画面導線と権限制御を守る
- UI文言のアサーション (`expect(response.body).to include("文言")`) は原則書かない
- 構造的アサーション（HTTP status、redirect先、DB state変更）を優先する

詳細なテスト方針（優先度、監視対象 spec、追加すべきテストの指針等）は `docs/テスト方針.md` を参照。

#[[file:docs/テスト方針.md]]

---

## 日本語表示の徹底

画面上に英語がそのまま表示されることがないようにする。エラーメッセージ、enumの選択肢、カラム名、ボタンラベル等すべて日本語で表示すること。

### ルール

- モデルの属性名は `config/locales/ja.yml` の `activerecord.attributes` で日本語化する
- enumの選択肢は日本語化する（enum_help 相当）
- 新しいモデルやカラムを追加したら、必ず同時にロケールファイルも更新する

---

## 実装時の必須ルール

### コード変更時の確認セット

1. 実装（コード変更）
2. 既存テストが壊れていないか確認（`bundle exec rspec` が通ること）
3. コアロジック変更時のみ、テスト追加 or 修正
4. seed影響確認（テーブル変更時）

### テーブル設計変更時のseed確認

テーブルの追加・カラム変更・削除等を行った場合は、`db/seeds.rb` および `db/seeds/` 配下のseed関連ファイルに影響がないか必ず確認すること。

---

## Git操作

### ルール

- git操作は可能な限り **`gh` CLI** を使う（push, pull, branch 操作, PR作成・管理等）
- `gh pr create`, `gh pr close`, `gh pr merge`, `gh pr list` 等を優先する
- ブランチのpushは `git push` でよいが、PR関連操作は必ず `gh` を使う
- `gh` で対応できない低レベル操作（rebase, conflict解決等）のみ素の `git` コマンドを使う
