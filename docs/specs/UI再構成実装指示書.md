# docs-portal UI/UX改善 実装指示書

## ― 業務システムと文書管理SaaSの中間を狙うUI再構成 ―

## PR分割と優先度

| PR | 内容 | 優先度 | 状態 |
|----|------|:------:|------|
| 1 | User/Admin Shell分離・Global Navigation | P0 | 実装済み |
| 2 | TOPをHome化・Dashboard再構成・Global Search | P0 | 実装済み |
| 3 | Admin一覧共通layout・新規登録折りたたみ・Filter Toolbar | P0 | 一部実装（会社・ユーザー・案件・文書・案件所属） |
| 4 | 文書権限のtab化・pagination | P0 | 実装済み |
| 5 | Admin Dashboardと運用診断の分離 | P0 | 実装済み |
| 6 | `/documents` 検索UI簡素化・Project workspace調整 | P1 | 一部実装（`/documents`検索UI） |
| 7 | 保存済み画面のtab化 | P1 | 実装済み |
| 8 | 監査ログFilter/Export/Page size整理 | P1 | 実装済み |
| 9 | 一括編集・長大画面のstep化 | P1 | 実装済み |
| 10 | Radius/Shadow/Button/Card等のvisual polish | P1 | 未着手 |

---

## PR 1: User/Admin Shell分離

### 目的
利用者画面と管理コンソールを別レイアウト（Shell）に分離する。

### 対象ファイル（候補）
- `app/controllers/admin/base_controller.rb` — `layout "admin"` 指定
- `app/views/layouts/application.html.slim` — 利用者用（user shell）
- `app/views/layouts/admin.html.slim` — 管理用（admin shell）新規作成
- `app/views/shared/_navbar.html.slim` → 分割:
  - `app/views/shared/_user_navbar.html.slim`
  - `app/views/shared/_admin_navbar.html.slim`（headerのみ）
- `app/views/admin/_sidebar.html.slim` — 管理Sidebar新規作成
- `app/frontend/entrypoints/application.css` — admin layout / sidebar CSS

### 利用者Shell header構造
```
文書ポータル    [ 文書・案件を検索________________ ]
ホーム    文書 ▼    要対応 ▼    履歴 ▼
                                      ユーザー ▼
```

- ホーム: `/dashboard`
- 文書: すべての文書 / 案件から探す / 保存済み
- 要対応: アクセス申請 / 確認依頼(internalのみ)
- 履歴: 送付履歴 / 注意事項・同意履歴
- ユーザー: 名前 / メール / 管理コンソールへ(admin/company_master_adminのみ) / ログアウト

### 管理Shell構造
```
┌─────────────────────────────────────────────────┐
│ 文書ポータル   管理コンソール      利用者画面へ   user │
├──────────────┬──────────────────────────────────┤
│ Sidebar       │          Main workspace          │
└──────────────┴──────────────────────────────────┘
```

### Sidebar分類
- **概要**: 管理概要
- **組織・利用者**: 会社 / ユーザー / 案件 / 案件所属 / 同意文面 / 案件同意設定
- **文書・権限**: 文書 / 文書セット / 文書カタログ / 文書権限 / アクセス申請 / 文書利用状況 / 文書一括編集
- **取込・同期**: ZIPインポート / 単体ファイルdry-run / Git連携 / Git同期履歴 / Microsoft Graph / 外部フォルダ同期
- **通知・自動化**: Webhook設定 / Webhook送信履歴 / 定期ジョブ / 生成ファイルイベント / 生成ファイル実行履歴
- **監査・診断**: 監査ログ / API仕様 / モデルブラウザ / Storage / 運用診断

### 完了条件
- 利用者画面headerに「管理メニュー」「連携メニュー」が表示されない
- adminはユーザーメニューから「管理コンソールへ」移動できる
- admin画面には管理専用Sidebarが存在する
- admin画面から「利用者画面へ戻る」が常に確認できる
- active項目がaria-current + 視覚で判別できる
- mobileではSidebarをdrawer/折りたたみ式にする
- 既存権限制御は変更しない
- 各admin view内の `= render "admin/nav"` を整理

---

## PR 2: TOPをHome化・Dashboard再構成・Global Search

### 目的
rootを `/dashboard` に変更し、利用者ホームを再構成する。
headerにGlobal Searchを追加する。

### route変更
```ruby
root "dashboard#show"
```

### Dashboard再構成
優先順位:
1. **要対応** — 保留中の処理がある場合のみ強調。0件なら小さく「対応項目なし」
2. **最近見た文書** — ホームの主役。5〜8件表示
3. **保存済み** — お気に入り/後で読むを小さく
4. **最近更新された文書** — 更新日時明示
5. **案件** — 下部または右rail

workspace summary: `5案件 ・ 184文書 ・ 保存済み0件` 程度に縮小

削除: 「社内向け導線」card

### Global Search
利用者headerに `[ 文書・案件を検索 ]` を追加 → `GET /documents?q=...` へ送る

### Homeから一覧への導線
- `最近見た文書`に候補がある場合の`すべて見る`は`GET /document_bookmarks?view=recent`へ直接つなぐ
- `最近見た文書`が0件の場合の`文書を探す`は`GET /documents`を維持する
- `最近更新された文書`とGlobal Searchは案件横断の`GET /documents`を入口にする

---

## PR 3: Admin一覧共通layout

### 目的
管理一覧の「新規登録フォーム→検索→一覧」構造を整理する。

### 変更後構造
```
タイトル                             [+ 新規登録]
[検索________________] [状態▼] [検索] [詳細条件▼]
184件   [filter chip]                 [列設定 ⚙] [一括操作▼]
──────────────────────────────────────────────
一覧
```

### 新規登録
- `<details>` で閉じた状態
- validation error時は自動open
- company_master_adminの自社情報は例外的に常時表示

### Search
常時: キーワード + 頻出条件1〜2個
詳細: Disclosureで追加条件

### Full-width action button廃止
Desktop: content-width button
Mobile: full-width許可

---

## PR 4: 文書権限のtab化・pagination

### 目的
39,597pxの巨大ページを解消する。

### 変更
- tab: `?view=assignments`（権限一覧）/ `?view=overview`（文書別概要）
- デフォルト: assignments
- 25件/page
- 新規登録: 閉じたDisclosure
- CSV: 現在の全件出力維持
- active tabだけをserver-renderし、全tabの`aria-controls`は応答内に存在する単一tabpanelを参照する
- 選択中tabだけをTab順に置き、左右矢印・Home・Endでfocusを移動するmanual activationとする。Enter/Spaceで遷移し、選択状態は遷移後のserver responseで確定する

---

## PR 5: Admin Dashboard分離

### 目的
6,136pxの管理Dashboardから詳細診断を分離する。

### `/admin` に残すもの
- 要対応（異常件数のみ強調）
- 主要件数（会社/ユーザー/案件/文書）
- 最近の運用状態（最大数件）

### 新設: `/admin/diagnostics`（運用・診断）
- Configuration diagnostic全項目
- storage詳細
- model observation詳細
- 継続失敗候補詳細
- runbook導線

---

## PR 6: `/documents`検索UI簡素化・Project workspace調整

### 目的
案件横断の閲覧可能文書一覧で、初回表示の検索フォームを短くし、文書へ到達するまでの導線を単純化する。

### `/documents`の検索構造
- 常時表示: `キーワード`、`案件`、`タグ`
- `追加条件` Disclosure: `カテゴリ`、`ファイル種`、`公開範囲`、`HTML生成済み`、`添付あり`、`PDFあり`、`図あり`
- 追加条件が1つでも有効な場合はDisclosureをopenで再描画する
- 追加条件は常時条件と同じGET form内に残し、送信・rparam・paginationのparam契約を変えない
- 検索scope、認可、RTPの`table_key = :accessible_documents`は変更しない

### Project workspace
今回の`/documents`修正とは分離し、既存の案件詳細・文書ツリー・ZIP導線を壊さない。追加調整は別の実装単位で行う。

---

## PR 7: 保存済み画面のtab化

### 目的
`お気に入り`、`後で読む`、`最近見た文書`の3section同時描画をやめ、選択中の用途だけを短く確認できるようにする。

### 変更
- tab: `?view=favorite` / `?view=read_later` / `?view=recent`
- デフォルトと不正値のfallback: `favorite`
- 1回の応答ではactive tabに対応する`tabpanel`だけを描画する
- favorite / read_laterでは保存済みfilter、recentではrecent専用検索だけを表示する
- タブ切替、検索、条件クリア、pager、`解除`、`お気に入りへ移す`で`view`を保持する
- Refererがない行操作でも、許可済みnavigation paramから同じtabのfallback URLを組み立てる
- favorite / read_laterの20件pagination、readable scope、bookmarkの保存仕様は変更しない
- Dashboardの`最近見た文書`にある`すべて見る`は`view=recent`へ直接つなぐ
- active tabだけをserver-renderし、全tabの`aria-controls`は応答内に存在する単一tabpanelを参照する
- 選択中tabだけをTab順に置き、左右矢印・Home・Endでfocusを移動するmanual activationとする。Enter/Spaceで遷移し、選択状態は遷移後のserver responseで確定する

---

## PR 8: 監査ログFilter/Export/Page size整理

### 目的
監査ログの初期表示を短くし、日常確認用のHTML一覧と持ち出し用CSVの件数境界を分離する。

### 変更
- HTML一覧は`accessed_at desc, id desc`のまま1ページ50件にする
- page linkは`前の50件` / `次の50件`とし、既存filterを保持する
- 1ページ50件化後も最大到達10,000行を維持し、任意の`limit` paramでは範囲を広げない
- 常時表示するfilterは`操作`、`対象種別`、`案件`に絞る
- AI context条件、会社、ユーザー、対象名/IP、文書名/URL識別子、開始日、終了日は同じGET form内の`高度条件` Disclosureへ移す
- 高度条件が1つでも有効な場合はDisclosureをopenで再描画する
- `現在の条件でCSV export（最新200件）`は主導線として常時表示する
- 表示中ページCSV（最大50件）、latest/current pageのmetadata JSON、scope説明は初期状態を閉じた`export補助` Disclosureへ移す
- latest CSV / metadataの`row_limit`は200、current page CSV / metadataの`row_limit`は50とする
- RTPの`table_key = :admin_access_logs`、列定義、認可、filter param、CSV固定列は変更しない

---

## PR 9: 一括編集・長大画面のstep化

### 目的
文書一括編集の対象選択tableによるページ全体の長大化を抑え、業務上の主操作と技術確認導線を分離する。

### 変更
- 対象文書tableは同じform内のフォーカス可能なスクロール領域へ入れる
- desktopでは対象領域を`max-height: 450px`、`overflow-y: auto`とし、table headerをsticky表示する
- server-side paginationは追加せず、画面内検索、選択済みだけ表示、checkbox stateを維持する
- `bulk_edit[document_ids][]`のsubmit payload、handoff上限50件、read-only JSON schemaは変更しない
- `選択状態JSONを確認`は同じform内の初期状態を閉じた`技術JSONを確認` Disclosureへ移す
- `事前確認を作成`と`文書一覧へ戻る`は常時表示する
- 対象選択tableはindex一覧ではないためRTPを導入しない

---

## スクリーンショット検証条件

`bin/all_test`のdesktop撮影では、標準resource routeに加えて、UI再構成で追加・分離した主要custom routeとtab状態を個別に残す。

- `accessible_documents_index`: `/documents`
- `admin_diagnostics_index`: `/admin/diagnostics`
- `admin_document_permissions_assignments`: `/admin/document_permissions?view=assignments`
- `admin_document_permissions_overview`: `/admin/document_permissions?view=overview`
- `document_bookmarks_favorite`: `/document_bookmarks?view=favorite`
- `document_bookmarks_read_later`: `/document_bookmarks?view=read_later`
- `document_bookmarks_recent`: `/document_bookmarks?view=recent`

文書権限と文書ショートカットは状態名付きcaptureを正本とし、default indexと同じ画面を重複生成しない。各targetは同じbasenameのPNG / HTMLを生成し、画面操作ガイドでは日本語の状態名と操作説明へ対応付ける。mobile captureはこの検証単位に含めない。

---

## Visual Polish方針（PR 10）

### Card
- radius: 8〜12px（現在の18〜22pxから縮小）
- shadow: なし or 非常に弱い
- border: neutralに（orange限定はbrand/active/accentのみ）

### Button
- radius: 6〜8px（pill廃止）
- pill許可: status badge / filter chipのみ

### Background
- neutral薄色基本
- body gradient廃止

### 密度ルール
- 利用者: row 44〜52px, padding 12〜20px
- 管理一覧: row 36〜44px, compact form
- Confirmation: 低密度（余白多め）

---

## Tooltip使用ルール（追加）

### 付けるもの
- 正本区分、最新版/HTML、継続失敗候補、lifecycle関連の特殊状態
- 操作の前提条件・影響範囲

### 付けないもの（意味が自明）
- 案件、お気に入り、後で読む、最近見た文書、最近更新された文書
- ユーザー、会社

### 禁止
- 重要情報をTooltipだけに隠す（validation error、warning、destructive影響は常時表示）

---

## 禁止事項
- 認可ロジック変更
- domain model / DB schema変更
- 関連gem修正
- RTP table_key一括変更
- SPA化
- 巨大CSS全面置換
- Tooltip全面削除
