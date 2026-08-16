# docs-portal UI/UX改善 実装指示書

## 1. 目的

現在のUI構造をベースとして、業務システムとしての操作効率・安全性を維持しつつ、Box系SaaSに近い整理された視覚品質まで引き上げる。

今回、大規模な画面再設計は行わない。次の実装済み構造は維持する。

- 利用者画面 / 管理画面のShell分離
- 管理画面のSidebar構成
- 管理一覧のlist-first化（会社・ユーザー・案件・文書・案件所属等の実装済み画面）
- 案件詳細の「左文書ツリー + 右Workspace」
- 文書権限のAssignments / Overview tab
- 保存済みのFavorite / Read later / Recent tab
- `/documents`の基本条件 + 追加条件Disclosure
- 一括編集のStepper + 対象一覧scroll
- Admin Dashboard / Diagnosticsの分離
- 監査ログの50件pagination / CSV分離

この文書は後続実装の指示書である。未実装項目をcurrent behaviorとしてrunbookへ記載しない。

モバイル対応は今回の対象外とし、1440pxを基準とするPC表示を優先して最適化する。既存のレスポンシブ表示を意図的に壊してよいという意味ではない。

---

## 2. 最重要方針

現在の主な問題は画面構造ではなく、CSSの責務境界、色体系、情報密度、操作優先度の視覚表現にある。特にCSS基盤整理をP0として先に行う。

### Global selectorを見た目の責務から外す

プロダクト固有の見た目を次のようなglobal tag selectorへ持たせない。

```css
header { /* ... */ }
main { /* ... */ }
button { /* ... */ }
input { /* ... */ }
```

原則としてclass selectorへscopeする。

```css
.app-header {}
.user-nav {}
.admin-header {}
.app-main {}
.page-header {}
.button {}
.form-control {}
```

最低限、次の副作用を解消する。

- `header`のstyleが`.page-header`、user navbar wrapper、Admin Dashboard headerへ漏れない
- `main`の白背景・border・shadow・radiusが`.admin-main`へ漏れない
- bare `button` ruleがAdmin Sidebar toggleやColumn Settingsへ漏れない
- `input { width: 100% }`がsubmit buttonまで横100%にしない
- `bootstrap_overrides.css`がcomponent専用CSSを意図せず上書きしない

専用componentのstyleをgeneric Bootstrap overrideより優先する。`:root`のtoken定義と最小限のresetだけをglobal selectorの例外とする。

---

## 3. デザイントークン

デザイントークンの名称・値は [閲覧画面とUI](./閲覧画面とUI.md#design-tokens) の「Design tokens」を唯一の正本とする。この実装指示書では値を再定義せず、色・radius・shadowを正本のtokenから参照する。実装中に追加の階調が必要になった場合も、先に恒久仕様へtokenを追加してから使用する。

Action Blueは1系統に統一する。Orangeはブランド用途に限定し、Card border、generic badge、検索領域、通常情報へ使わない。通常情報はNeutral、操作はAction Blue、Brandは限定的にOrange、Warning / Dangerはsemantic colorとする。

---

## 4. Surface / Card / Admin Main

基本Surfaceから淡いOrange borderとPeach gradientを外す。

```css
.card {
  background: var(--ui-surface);
  border: 1px solid var(--ui-border);
  border-radius: var(--ui-radius-lg);
}
```

通常Cardにはshadowを付けない。ShadowはDropdown、Dialog、Popover、Floating panelなど、本当に浮いているUIだけに使う。

`.admin-main`へglobal `main`のSurface designを適用しない。

```css
.admin-main {
  margin: 0;
  max-width: none;
  background: transparent;
  border: 0;
  border-radius: 0;
  box-shadow: none;
}
```

Admin画面は次の階層とし、画面全体を1枚の巨大Cardで囲わない。

```text
Neutral page background
 ├ Screen title
 ├ Filter toolbar
 ├ List meta
 └ Table / 必要なCard
```

---

## 5. Radius / Shadow / Typography

### Radius

| 用途 | Radius |
| --- | ---: |
| 小要素 | 4px |
| Button / Input / Badge | 6px |
| Card / Panel | 8px |
| Dialog / Dropdown | 10〜12px |
| Count pill | 999px |

案件文書ツリーSidebarの22px radiusは`0 8px 8px 0`程度へ縮小する。通常Surfaceの`0 18px 45px`級shadowは廃止する。

### Typography

| 要素 | サイズ |
| --- | ---: |
| H1 | 26〜28px / 700 |
| H2 | 20px / 700 |
| H3 | 16px / 700 |
| Public Body | 15px |
| Admin Body | 14px |
| Table | 13.5〜14px |
| Table header | 13px / 600 |
| Help / Caption | 12〜13px |

Admin H1で32px以上を常用しない。

---

## 6. Badge / Code / Chip

Generic `.badge`はNeutralとする。

```css
.badge {
  background: var(--ui-surface-muted);
  color: var(--ui-text-subtle);
  border-radius: var(--ui-radius-md);
}
```

状態に意味がある場合だけ`badge--info`、`badge--success`、`badge--warning`、`badge--danger`等のmodifierを使う。「仕様」「管理者」「閲覧者」「最近見た文書」などをOrangeで表示しない。

案件コード等が警告色に見えないよう、ID / codeは補助情報としてNeutral表示する。

```css
.identifier-code,
table code {
  color: var(--ui-muted);
  background: transparent;
  font-size: 0.85em;
}
```

Badge / Status / Filter chipのradiusは6px、件数だけpillとする。generic UIをすべてpillにしない。

---

## 7. Button hierarchy / Row Action

### Primary

登録、保存、検索、dry-run作成、実行。Solid Action Blueとする。

### Secondary

戻る、CSV、新規登録Disclosure、補助操作。White / Outlineとする。

### Utility

列設定、技術詳細、metadata、表示設定。Neutral outline / Ghostとする。

### Danger

通常状態ではsolid redを使わない。

```css
.button.danger {
  background: var(--ui-surface);
  color: var(--ui-danger-text);
  border-color: var(--ui-danger-border);
}

.button.danger:hover {
  background: var(--ui-danger);
  color: var(--ui-on-action);
}
```

一覧にsolid red buttonを反復表示しない。行操作は共通化し、最低でも編集をneutral / secondary、削除をoutline dangerとする。低頻度操作はoverflow menuへまとめることを検討する。icon-onlyの場合はBootstrap Icons、対象を特定できる`aria-label`、`title`を必須とする。操作列幅は実際のボタン数とラベルに合わせ、110pxを全画面固定値にしない。

---

## 8. Form / Search / Column Settings

PC画面の検索・submit buttonを横100%にしない。`input { width: 100% }`を廃止し、text系inputだけを対象にする。

```css
input[type="text"],
input[type="search"],
input[type="email"],
input[type="date"],
input[type="datetime-local"],
select,
textarea {
  width: 100%;
}
```

基本配置は次とし、検索buttonは80〜120px程度のcontent widthとする。

```text
[キーワード________] [状態▼] [会社▼] [検索]
```

検索領域は通常Cardと同じNeutral borderを使う。Orange borderは使わない。Filterが有効な場合だけ`border-left: 3px solid var(--ui-action)`等の状態表示を検討する。

列設定はPrimary操作に見せない。

```css
.column-settings__summary {
  background: var(--ui-surface);
  border: 1px solid var(--ui-border-strong);
  color: var(--ui-text-subtle);
}
```

---

## 9. Table / Pagination

一覧は比較しやすい高密度UIとする。

```css
th {
  padding: 8px 10px;
  background: var(--ui-surface-subtle);
  color: var(--ui-text-subtle);
  font-size: 13px;
  font-weight: 600;
}

td {
  padding: 8px 10px;
  font-size: 14px;
}

tbody tr:hover td {
  background: var(--ui-surface-hover);
}
```

Header rowとbodyを薄いGrayで区別する。RTPの列表示、列順、列幅、固定列、`table_key`、scroll wrapper契約は変更しない。

`total_pages == 1`の場合はpagerを表示しない。総件数は表示するが、`前へ（先頭） / 1 / 1ページ / 1ページのみ / 次へ（最終）`は出さない。CSV等のexportはpagerと独立して表示する。

---

## 10. Admin Sidebar / 利用者Navbar / PageHeader

### Admin Sidebar

構造は維持する。section headingを11.5px程度、通常linkの行高を30〜32px程度とする。PCでhamburgerを表示しない。`.admin-sidebar__toggle { display: none; }`がgeneric button ruleに負けないselector設計にする。

### 利用者Navbar

White Navbarを維持する。Dark Header用colorをDropdown summaryへ流用しない。

```css
.user-nav .nav-dropdown__summary {
  color: var(--ui-text-subtle);
}

.user-nav .nav-dropdown__summary:hover,
.user-nav .nav-dropdown__summary.is-active {
  color: var(--ui-action);
}
```

Global `header`のbackground / shadowをUser Navbar wrapperへ漏らさない。

### PageHeader

案件詳細や閲覧可能文書のDark PageHeaderは維持できるが、global `header`ではなく`.page-header`へscopeする。

```css
.page-header {
  padding: 18px 20px;
  border-radius: var(--ui-radius-lg);
  background: var(--ui-page-header);
  color: var(--ui-on-action);
  box-shadow: none;
}

.page-header__subtitle {
  color: var(--ui-page-header-subtitle);
}
```

---

## 11. 画面別改善

### 管理概要

現在の構造は維持する。Dashboardだけ紺色Headerにならないようtag selector依存をなくし、他のAdmin画面と同じ`管理概要 [運用・診断]`の見出しにする。

Metricは数字を最重要情報にする。0件は弱く、異常ありだけAmber / Redのsemantic accentを使う。各Metricは次のDiagnostics該当箇所へ直接つなぐ。

- 設定診断: `/admin/diagnostics#configuration`
- 文書実体欠落: `/admin/diagnostics#document-files`
- 継続失敗候補: `/admin/diagnostics#failures`

「最近の問題」は「最近の運用失敗」等へ変更し、設定警告とは別概念であることを明確にする。

### 運用・診断

最上部から正常モデルを大量表示しない。次の順序を基準にする。

```text
運用・診断
[要対応] [失敗] [設定] [ファイル] [Storage] [モデル]
要対応
運用失敗
設定診断
文書ファイル健全性
Storage
モデル観測
```

モデル観測は最後に置き、正常項目はDisclosureへ格納する。Model Browserで確認できる正常モデルは`32モデル / 最終更新 / モデルブラウザを開く`程度へ要約できる。read-only境界を維持し、再試行・削除・cleanup等を追加しない。

### Users一覧

デフォルト列幅の合計を見直し、1440pxで操作列まで確認できるようにする。

```text
表示名 180 / メール 240 / 種別 110 / 会社 180 / 状態 80 / 操作 100
```

「ユーザー名（表示用）」と「表示名」のどちらかをdefault hiddenにし、利用者が意味を区別できる日本語名へ整理する。

### Projects一覧

長い案件codeが案件名へ重ならないよう、code幅は180px前後、overflowはellipsisとする。完全値へtitle / tooltip等から到達できるようにする。表示用語は「企業」ではなく「会社」へ統一する。

### `/documents`

基本条件 + 追加条件Disclosureを維持する。件数、pagination、列設定を近い位置へ集約する。ヒット理由は`q.blank?`時にdefault hiddenとし、キーワード検索時だけ表示する。最終更新は2行へ折り返さない幅を確保し、必要なら`08/13 23:09`程度へ短縮する。

### 保存済み

3状態のserver-rendered構造を維持する。Tabで状態が明示されている場合、`対象: お気に入り`や各行の`最近見た文書`等を重複表示しない。Badgeは各行で異なる状態を示す場合だけ使う。Filter見出しは16px程度とする。

### Home

現在の構造を維持する。冒頭の`5案件・184文書・保存済み0件`では数字を`font-weight: 700`、`var(--ui-text)`程度に強調する。Cardを増やさず、Document listのhover領域を行全体へ広げる。

### 一括編集

scroll table + Stepperを維持する。Primary buttonは次を両方満たすまでdisabledにする。

```text
対象文書 >= 1件
AND
変更内容 >= 1項目
```

0件時は`対象文書を1件以上選択してください。`、変更なしは`変更する項目を1つ以上指定してください。`と表示する。`事前確認を作成`を横100%にせず、戻るを左、Primary CTAを右に置く。Inactive Stepは現在より少し濃いGrayとする。

### 文書権限

tab / pagination / CSV構造を維持する。全幅Search、Orange badge、solid red delete、Primary相当の列設定を共通ルールへ合わせる。

各tabの`aria-controls`は対応する固定panel IDを指定し、inactive tabがactive panel IDを参照しない。

```text
権限一覧 → document-permissions-assignments-panel
文書別概要 → document-permissions-overview-panel
```

active viewだけをserver-renderする契約、view param、filter、CSV、RTP `table_key`は変更しない。

---

## 12. 用語統一

画面表示とScreen Guideは最低限、次へ統一する。route / controller / internal keyは変更しない。

| 旧表記 | 表示用語 |
| --- | --- |
| 企業 | 会社 |
| ショートカット | 保存済み |
| ダッシュボード（利用者側） | ホーム |
| 管理ダッシュボード | 管理概要 |
| Diagnostics / 運用診断 | 運用・診断 |
| アクセスログ | 監査ログ |

「ユーザー名（表示用）」と「表示名」はDB field名を露出するのではなく、利用者が用途を区別できる名称へ整理する。

Screen Guideは生成物を直接編集せず、`script/generate_screen_docs.ts`のmetadataを修正後に`bin/all_test`で再生成する。`root`と`dashboard`が同一画面なら別Screenとして重複掲載しない。次の状態別captureは維持する。

- document permissions assignments
- document permissions overview
- bookmarks favorite
- bookmarks read_later
- bookmarks recent
- accessible documents
- admin diagnostics

---

## 13. Empty State

通常のデータ0件と「正常」を分ける。管理概要の`問題なし`等は大きなEmpty Stateにせず、`✓ 最近の運用失敗はありません`程度のcompact表示を使える。

---

## 14. 実装順序

### Phase 1 — CSS foundation

1. Global `header/main/button/input` selector整理
2. Bootstrap overrideの責務整理
3. Action colorを1系統へ統一
4. Admin main Surface解除
5. Card border / background neutral化
6. Badge / code color neutral化
7. Radius / shadow token統一

### Phase 2 — 共通Component

8. Button variants
9. Table
10. Column Settings
11. PageHeader
12. Admin Sidebar
13. Filter Toolbar / Chip
14. Empty State

### Phase 3 — 画面別

15. Admin Dashboard
16. Diagnostics
17. Users
18. Projects
19. Document Permissions
20. `/documents`
21. Bookmarks
22. Bulk Edit
23. Home

### Phase 4 — Polish

24. 用語統一
25. Screen Guide整理
26. Screenshot比較
27. UI regression spec追加

PhaseごとにPC screenshot / HTML snapshotを残し、global selectorやtoken逸脱を検査する。モバイル固有変更を混ぜない。

---

## 15. 第2波 — 入力幅・List Footer・フォーム階層

第1波で整えたShell、Neutral surface、RTP、FilterToolbar、StatusBadge、SSR navigationを維持し、次の順で仕上げる。

### Phase 5 — 共通Visual基盤

28. `FilterToolbarComponent::FieldComponent`へkeyword、remote、enum、date、short、wideの用途variantを追加する
29. 一覧Filter内の`width: 100%`をfield wrapper内へ限定し、検索・クリアbuttonをcontent widthへ揃える
30. `ListFooterComponent`を追加し、表示範囲、page navigation、page jump、総ページ数、export slotを共通化する
31. 既存pagination hashと画面固有page parameterをComponent入力へ正規化し、CSV scopeを変更しない
32. 右端ユーザーメニューをright aligned + viewport clampとし、Escape・外側click・focus returnを維持する
33. 編集・新規画面へstandard / wideの用途別form containerを追加する
34. Primary / Secondary / Utility / Dangerの用途を再確認し、列設定・metadata・技術詳細をUtilityへ統一する

### Phase 6 — 代表画面

35. Webhook送信履歴を標準FilterToolbarへ移し、remote combobox、enum、HTTP、error query、date rangeを内容別幅で配置する
36. Webhookの常時Helpをlabel / placeholder / tooltip / 閉じたDisclosureへ整理する
37. WebhookのRTP `table_key`、selected restore、filter warning、詳細へのreturn context、100件paginationを維持したままList Footerへ移す
38. Webhookの一覧Metaを`開始–終了 / 総件数`へ簡潔化する

### Phase 7 — 一覧横展開

39. Companies、Users、Projects、Documents、Memberships、Document permissionsへFilter field variantとList Footerを適用する
40. 監査ログ、外部送付履歴、既読確認、生成ファイルevent/runは既存のpagination・CSV・retry scopeをadapterで維持してfooterだけ共通化する
41. Status、Type、Date、Datetime、Count、HTTP、Actionsへ内容基準のRTP `default_width`を設定し、title / name / notesはflexibleのまま残す
42. 生成ファイルevent/runの技術Helpと重複状態filterを整理し、現在条件に一致する失敗最大100件だけを対象にする契約を維持する

### Phase 8 — Form / Integration / Brand polish

43. Webhook、Git、外部フォルダ同期、Microsoft Graphの編集画面を用途別form containerへ収める
44. Integration画面を「接続状態 → 入力 → 保存 → 初めて設定する場合」の順へ整理し、技術手順をDisclosureへ移す
45. Admin DashboardのCard-in-Cardを解消し、異常値だけsemantic accentを残す
46. Login、User Navbar、Admin Header、Sidebar active railへ限定的なBrand Orangeを維持する
47. screen scenarioの業務説明を更新し、`screen_guide.md`は生成処理だけで更新する

---

## 16. 禁止事項・不変条件

- 認可ロジックを変更しない
- domain model / DB schemaを変更しない
- 関連gemのpublic APIを変更しない
- RTP `table_key`を変更しない
- search / export / pagination / dry-run payloadの業務契約を変更しない
- SPA化しない
- 巨大CSS全面置換を1回で行わない
- Tooltipを全面削除しない
- currentのlist-first / tab / Disclosure / Shell構造を崩さない
- モバイル固有変更を今回のPhaseへ混ぜない

---

## 17. 完了条件

- PC Adminで不要なhamburgerが表示されない
- Admin main全体が巨大な白Cardにならない
- Public NavbarにDark Header用color / shadowが漏れない
- PageHeader subtitleがDark background上で明瞭に読める
- Search / Submit buttonが意図せず横100%にならない
- Primary / Secondary / Utility / Dangerが視覚的に区別できる
- Column SettingsがPrimary buttonに見えない
- Generic badgeがOrange warning風に見えない
- ID / codeが赤・ピンクに見えない
- Table headerとbodyが視覚的に区別できる
- 1440pxで主要Admin一覧の操作列まで無理なく確認できる
- 1ページだけの一覧に不要なpagerが表示されない
- Diagnosticsで異常情報へすぐ到達できる
- Dashboardから異常詳細へ直接遷移できる
- Bulk Editで対象0件・変更0件のdry-runを開始できない
- 同一概念の用語が画面間とScreen Guideで統一される
- 既存のlist-first / tab / Disclosure / Shell構造を崩していない
- モバイル固有変更が混ざっていない

## 最終判断基準

画面を豪華にするのではなく、重要なものだけを強くし、それ以外を静かにする。

通常情報はNeutral、操作はBlue、Brandは限定的にOrange、Warning / DangerはSemantic colorとし、余白・色・影・borderのすべてに意味を持たせる。
