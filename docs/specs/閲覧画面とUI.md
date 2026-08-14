# 閲覧画面とUI

この文書は、利用者画面、管理画面、viewer 導線の正本です。

## Visual design system

### 基本原則

- 画面を豪華にするのではなく、重要なものだけを強くし、それ以外を静かにする
- 通常情報はNeutral、操作はAction Blue、ブランドは限定的にOrange、警告・危険はsemantic colorで表す
- UI構造、認可、業務scope、RTP `table_key`、rfk入力、dry-run境界はvisual改善のために変更しない
- 管理画面は1440pxを基準にPC優先で検証する。今回のvisual改善ではモバイル固有の再設計・撮影を行わないが、既存レスポンシブ表示を意図的に壊さない

### CSS責務境界

- `:root`のtoken定義と最小resetを除き、`header`、`main`、`button`、`input`等のbare element selectorへプロダクト固有の見た目を持たせない
- Shellとcomponentの見た目は`.app-header`、`.user-nav`、`.admin-header`、`.admin-main`、`.page-header`、`.button`、`.form-control`等のclassへscopeする
- component専用CSSをgeneric Bootstrap overrideより優先し、`bootstrap_overrides.css`からSidebar toggle、Column Settings、RTP editor等を意図せず上書きしない
- global `header`のdark background / shadowをUser NavbarやAdmin Dashboard headerへ漏らさない
- global `main`のsurfaceを`.admin-main`へ漏らさず、Admin workspace全体を巨大な白いCardにしない
- bare `button` ruleでSidebar toggleやutility buttonをPrimary化しない
- `input { width: 100% }`を使わず、text系input、select、textareaだけをfull width対象にする。submit buttonはPCでcontent widthとする

### Design tokens

```css
:root {
  --ui-bg: #f6f8fb;
  --ui-surface: #ffffff;
  --ui-surface-subtle: #f8fafc;
  --ui-surface-muted: #f1f5f9;
  --ui-surface-hover: #fafcff;
  --ui-text: #1f2937;
  --ui-text-subtle: #475569;
  --ui-muted: #64748b;
  --ui-on-action: #ffffff;
  --ui-border: #e2e8f0;
  --ui-border-strong: #cbd5e1;
  --ui-action: #0f62fe;
  --ui-action-hover: #0b57d0;
  --ui-action-soft: #eff6ff;
  --ui-brand: #ff5000;
  --ui-success: #15803d;
  --ui-warning: #b45309;
  --ui-danger: #dc2626;
  --ui-danger-text: #b91c1c;
  --ui-danger-border: #fecaca;
  --ui-page-header: #102a43;
  --ui-page-header-subtitle: rgba(255, 255, 255, 0.72);
  --ui-radius-sm: 4px;
  --ui-radius-md: 6px;
  --ui-radius-lg: 8px;
  --ui-shadow-floating: 0 8px 24px rgba(15, 23, 42, 0.12);
}
```

- Orangeはブランド用途に限定し、通常Card、検索領域、generic badge、ID / codeへ使わない
- 通常Cardはwhite surface、neutral border、8px radius、shadowなしを基本とする
- ShadowはDropdown、Dialog、Popover、Floating panel等の浮いているUIだけに使う
- radiusは小要素4px、Button / Input / Badge 6px、Card / Panel 8px、Dialog / Dropdown 10〜12px、件数pill 999pxを基準とする

### Typographyと密度

- H1は26〜28px / 700、H2は20px / 700、H3は16px / 700を基準とし、Admin H1で32px以上を常用しない
- Public Bodyは15px、Admin Bodyは14px、tableは13.5〜14px、table headerは13px / 600、help / captionは12〜13pxを基準とする
- 管理一覧のrowは36〜44px程度とし、Header rowをneutral grayでbodyから区別する

### SurfaceとShell

- Adminはneutral page backgroundの上にScreen title、Filter toolbar、List meta、Table / 必要なCardを置く
- `.admin-main`はtransparent、borderなし、radiusなし、shadowなしとし、画面全体を1枚のCardで囲わない
- 利用者Navbarはwhiteを維持し、Dropdown summaryはneutral text、hover / activeだけAction Blueとする
- Dark PageHeaderは`.page-header`へscopeし、subtitleを`rgba(255, 255, 255, 0.72)`程度で明瞭にする
- desktopではAdmin Sidebarのhamburgerを表示しない。headingは11.5px程度、link行高は30〜32px程度とする

### Button / Badge / Code

- Primaryは登録、保存、検索、dry-run作成、実行に限定し、Solid Action Blueとする
- Secondaryは戻る、CSV、新規登録Disclosure、補助操作に使い、white / outlineとする
- Utilityは列設定、技術詳細、metadata、表示設定に使い、neutral outline / ghostとする
- Dangerは通常white + danger text / borderとし、hover時だけsolid dangerにする。一覧でsolid red buttonを反復しない
- generic `.badge`、role、カテゴリ、Filter chipはNeutralを基本とし、semanticな状態だけStatusBadge modifierを使う
- Badge / Status / Filter chipのradiusは6px、件数だけpillとする
- `table code`と`.identifier-code`はmuted neutralで表示し、警告色に見せない

### Table / Row action / Pagination

- table headerは`var(--ui-surface-subtle)`、13px / 600、bodyは14pxを基準にする。hoverは薄いneutral blueだけを使う
- 主識別子を第一導線にし、操作列には現在許可された補助操作だけを表示する
- 編集はneutral / secondary、削除はoutline dangerとし、低頻度操作はoverflow menuへまとめることを検討する
- icon-only操作にはBootstrap Icons、対象を特定できる`aria-label`、`title`を付ける。操作列幅は実際のボタン数に合わせ、110pxへ一律固定しない
- `total_pages == 1`ではpager navを表示しない。総件数は表示し、CSV等のexportはpagerと独立させる
- 1ページ時に`前へ（先頭）`、`1ページのみ`、`次へ（最終）`を表示しない

### Server-rendered tab

- 文書権限と保存済みはview queryによるserver-rendered tab構造を維持し、active viewだけを描画する
- 各tabの`aria-controls`は対応する固定panel IDを指定し、inactive tabがactive panel IDを参照しない
- 文書権限は`document-permissions-assignments-panel`と`document-permissions-overview-panel`を使う
- view param、filter、pager、行操作後の戻り先を維持する

### 表示用語

| 内部・旧表記 | 画面表示 |
| --- | --- |
| 企業 | 会社 |
| ショートカット | 保存済み |
| ダッシュボード（利用者側） | ホーム |
| 管理ダッシュボード | 管理概要 |
| Diagnostics / 運用診断 | 運用・診断 |
| アクセスログ | 監査ログ |

route、controller、model、DB field等の内部識別子はこの表示用語統一だけを理由に変更しない。

## 画面

- ブランド名クリックで TOP に戻る
- 管理画面は `admin` または `company_master_admin` がアクセス可能とする
- `admin` は全管理機能を利用できる
- `admin` は Project 編集画面から標準文書テンプレートの preview と適用を実行できる
- `admin` は案件単位の文書利用状況レポートを参照できる
- `admin` は管理メニューの「API仕様」から、ドキュメント更新用 internal import API の仕様を参照できる
- API仕様ページは `docs-src/api-specification.md` を Docusaurus build した HTML を same-origin iframe で表示する
- API仕様ページは source Markdown が生成済み HTML より新しい場合に build job を enqueue し、生成HTMLの鮮度確認は `BuildFreshnessGuard` で共通化する
- `company_master_admin` は自社の会社マスタ・自社ユーザー管理のみ利用できる
- 文書詳細では `tree_view` gem を使って「案件 > フォルダ > 文書」の左ペインツリーを表示する
- 案件一覧では案件詳細への「文書を見る」導線を各案件に明示し、案件詳細では「文書を読む」または「文書一覧」を主操作として表示する
- 案件詳細のZIP出力、AI向けコンテキスト、文書セット、文書カタログは補助操作として主操作から分離し、必要なときだけ展開できるようにする
- 本文プレビューを表示できる文書詳細では本文を文書情報パネルより先に配置し、セクションナビゲーションから閉じた文書情報パネル内へ移動するときはパネルを自動的に開く
- 一覧画面の列設定は共通の `ColumnSettingsComponent` で初期状態を折りたたみ、必要なときだけ展開する。RTP editor と table には同じ `table_key`、`columns`、`settings` を渡し、定義済みの全列を列設定から再表示できるようにする
- 管理画面の主要ナビゲーションは上部navbarを正本とし、各画面で全管理リンクを重複表示しない。`company_master_admin` には利用可能な会社・ユーザー管理だけの補助ナビゲーションを表示する
- 全画面で `html[lang="ja"]`、メインコンテンツへのスキップリンク、主要ナビゲーションのアクセシブルな名前、一意な `main-content` を提供する
- 管理一覧を含む横長テーブルは、キーボードフォーカス可能な横スクロール領域とcaptionを持ち、主要5〜8列だけを初期表示する。定義済みの残りの列は列設定から再表示できるようにする
- 状態・間隔・enumなどの業務値は日本語で表示し、`Translation missing` や内部コード値を利用者向け画面へ露出させない
- 画面には業務上判断する値と実行可能な操作を優先して表示し、項目の意味・入力制約は `InfoTooltipComponent`、操作結果・前提は `HelpTooltipComponent`、read-only境界やrunbookなど複数文の補足は初期状態を閉じたDisclosureへ移す。ページ見出しやカード本文の直下へ同じ説明を常時重複表示しない
- 管理診断は状態・カテゴリ・日本語の判定結果を通常表示し、環境変数名、内部check key、path、設定値などの技術詳細は行内の初期状態を閉じたDisclosureから確認できるようにする
- import入力画面のenumは日本語表示し、ファイル選択はキーボード操作可能なdropzoneを主表示とする。ブラウザ標準のファイル入力文言は重複表示せず、選択ファイル名を日本語の状態表示で伝える
- 管理一覧の複合検索はrfk入力へ統一し、短い状態列と操作列には内容に応じた初期幅を指定する。複数の状態を1セルへ表示する場合も主要値を2行以内にまとめ、詳細説明で行高を増やさない
- 管理マスタ一覧は `header + 閉じた新規登録Disclosure + filter toolbar + filter chips + 件数/列設定 + RTP table + 条件付きpagination` のlist-first順序へ統一し、validation error時だけ新規登録Disclosureを開く。pagerは2ページ以上の場合だけ表示する
- 案件所属一覧はlist-first順序へ統一し、案件・ユーザーのremote search、role、25件単位のpagination、最大100件の境界を維持する。RTP tableはcaptionとフォーカス可能な横スクロール領域を持ち、2ページ以上の場合だけtableの後にpaginationを配置する
- 文書マスタ一覧はキーワードとアーカイブ状態だけを常時表示し、カテゴリ、種別、公開範囲、正本区分、保管期限、廃棄候補を `詳細条件` Disclosureへ格納する。一括編集・lifecycle補助導線も初期状態を閉じたDisclosureに分離する
- tooltipの起動要素はBootstrap Iconsとアクセシブルな名前を持ち、hoverとkeyboard focusの両方で表示する。長文をtooltip内で切り捨てず、200文字を超える説明はDisclosureとして全文へ到達できるようにする
- RTP一覧は `table_preferences_table_tag` の `scroll_wrapper: true` を使い、横スクロールをtable本体ではなくフォーカス可能なwrapperへ持たせる。table本体はnative table layoutを維持し、列表示・列順・列幅・固定列のStimulus反映を妨げない
- RTP列設定は各行の日本語列名、表示、順序、幅を同じviewport内で確認できるnative `dialog` modalとする。desktopでは最大72rem、画面高80vh以内とし、列一覧をmodal内部でスクロールして操作ボタンを下部に維持する。Escape・背景クリック・閉じるボタンで閉じ、起動ボタンへfocusを戻す。table側で変更した列順・列幅は同じ`table_key`のeditorへ同期してから保存する
- RTPのtable rootにはpreset用targetが存在しないため、host controllerはtable rootでpreset取得を開始せず、busy状態によりheader DnD・resize handleが無効化されないようにする。editor rootのpreset保存機能は維持する
- 管理ユーザー一覧は、1440pxで操作列まで確認できるよう、デフォルト幅を`表示名 180 / メール 240 / 種別 110 / 会社 180 / 状態 80 / 操作 100`程度に収める。「ユーザー名（表示用）」と「表示名」は両方を初期表示せず、用途を区別できる日本語名に整理したうえで片方をdefault hiddenにする
- 管理案件一覧は、案件codeを180px前後・ellipsis表示とし、長いcodeが案件名へ重ならないようにする。完全値は`title`またはTooltipから確認できるようにし、会社を「企業」と表示しない
- 案件横断の閲覧可能文書一覧では、主要5〜8列だけを初期表示し、横長のテーブルは横スクロールで閲覧できるようにする
- 案件横断の閲覧可能文書一覧では、`キーワード`、`案件`、`タグ`を常時表示し、`カテゴリ`、`ファイル種`、`公開範囲`、`HTML生成済み`、`添付あり`、`PDFあり`、`図あり`は同じ検索form内の`追加条件` Disclosureへ格納する。追加条件が適用中の場合だけ初期表示を開く
- 案件横断の閲覧可能文書一覧では件数、条件付きpagination、列設定を近接配置する。`ヒット理由`はキーワード検索時だけ表示し、`q.blank?`ではdefault hiddenとする。`最終更新`は2行へ折り返さず、必要なら`08/13 23:09`程度へ短縮する
- 保存済み一覧は`お気に入り`、`後で読む`、`最近見た文書`の3タブとし、1回の応答ではactive tabのpanelだけを描画する。検索、条件クリア、ページ移動、行操作では`view`を保持し、不正な`view`は`お気に入り`へ正規化する
- 保存済み一覧は、active tabですでに用途が明示されている場合、`対象: お気に入り`や行ごとの`最近見た文書`等を重複表示しない。Badgeは行ごとに異なる状態を示す場合だけ使う
- ホームの`最近見た文書`に候補がある場合の一覧導線は`GET /document_bookmarks?view=recent`へ直接つなぎ、候補がない場合の`文書を探す`は`GET /documents`を維持する
- 文書ツリーの行は `Document` を単位とし、Markdown / HTMLだけでなく、元ファイルを主要表示対象とするPDF、Office、CSV / TSV、ZIPのfile-backed文書も表示する。画像やCSSなど本文付随assetを独立行にはしない
- 文書ツリーの注意表示はDocusaurus build状態だけでは判定せず、現在の利用者が最新版の生成HTMLまたは埋め込みviewerへ到達できない場合にだけ「プレビュー画面はまだ生成されていません」と表示する。HTML `DocumentFile`をsame-origin iframeで閲覧できる場合は注意表示を出さない
- Markdown文書で生成HTMLを利用できず元のMarkdownファイルをiframe表示している場合は、本文が閲覧できても正常な生成HTML表示とは扱わない。iframe直前に「元のMarkdownを表示中」を常時表示し、生成待機中・生成中・再試行予定・成果物復旧中・自動再試行停止の状態と次の動作を日本語で示す
- Markdown fallbackの注意表示は実際に選択された埋め込みファイルがMarkdownの場合だけ出し、PDF・画像・HTMLなど本来のfile viewer表示へ誤って適用しない。利用者向け画面にはrendererの内部エラー本文を露出させず、表示差異と再試行状態だけを示す
- 文書一覧と文書詳細の左ペイン `文書ツリー` では、閲覧可能な全案件を対象に、文書名・slug・元パス、および案件・顧客の名称・コード類で文書を絞り込める
- 案件・顧客の検索対象には、ポータル側の名称・案件コード・ドメイン・公開IDに加え、外部マスタ同期で保持している外部IDと名称・フリガナ・コード系の同期元属性を含める
- 文書ツリーの検索中は、一致した文書までの案件・フォルダ階層を一時的に展開し、保存済みの全閉状態や検索中の閉操作より検索結果表示を優先する。検索解除後は保存済みの開閉状態へ戻す
- 文書ツリーが100表示行を超える場合は100行単位で描画し、表示位置に応じて「戻る」と「次へ」を表示する。このページネーションはDB取得件数ではなくツリーの表示行を対象とする
- 文書詳細と版詳細の「添付・元ファイル」は、保持している相対 path を使って `tree_view` でフォルダ階層表示する
- Project 配下で文書カタログ一覧・詳細を表示できる
- 管理画面には、主要 model の件数・最近の record・既存 CRUD への入口を横断表示する `model browser` を持つ
- 403 / 404 / 400 は利用者向けエラー画面で表示し、平文レスポンスにはしない

## 管理画面の文書一括編集

- 対象文書tableは同じform内のフォーカス可能な領域に置き、desktopでは`max-height: 450px`、`overflow-y: auto`としてページ全体の長大化を抑える
- 対象領域を縦スクロールしても列見出しを確認できるよう、table headerをsticky表示する
- 画面内検索、選択済みだけ表示、checkbox state、`bulk_edit[document_ids][]`のsubmit payload、handoff上限50件は変更しない
- `選択状態JSONを確認`は業務上の主操作から分離し、同じform内の初期状態を閉じた技術JSON Disclosureへ格納する
- `事前確認を作成`と`文書一覧へ戻る`は通常のactionとして常時表示し、Primary CTAを横100%にしない
- `事前確認を作成`は「対象文書が1件以上」かつ「変更項目が1つ以上」の場合だけ有効にする
- 対象0件では`対象文書を1件以上選択してください。`、変更なしでは`変更する項目を1つ以上指定してください。`と日本語で理由を表示する
- Stepperのinactive stepは判別可能なneutral grayとする

## 管理画面の監査ログ

- HTML一覧は`accessed_at desc, id desc`の順で1ページ50件とし、page移動後もfilter条件を維持する
- HTMLの50件化後も従来の最大到達10,000行を維持し、任意の`limit` paramでは取得範囲を広げない
- `操作`、`対象種別`、`案件`を常時表示し、AI context条件、会社、ユーザー、対象名/IP、文書名/slug、開始日/終了日は同じGET form内の`高度条件` Disclosureへ格納する。高度条件が有効な場合だけ再表示時に開く
- `現在の条件でCSV export（最新200件）`は主導線として常時表示し、表示中ページCSV（最大50件）と2種のmetadata JSON・scope説明は初期状態を閉じたexport補助Disclosureへ格納する
- latest CSV/metadataの`row_limit`は200、current page CSV/metadataの`row_limit`は50として分離する
- RTPの`table_key = :admin_access_logs`、列定義、認可、filter param、CSV固定列は変更しない

## 管理画面の文書権限一覧

- 文書権限一覧は `assignments`（権限一覧）と `overview`（文書別概要）の2つのtabを持ち、初期表示は `assignments` とする
- 1回の応答ではactive tabの一覧だけを描画し、非active tabのtable・empty stateは描画しない
- 検索送信、条件クリア、ページ移動ではactive tabを維持し、tab切替時は1ページ目へ戻す
- 両tabとも25件単位でページ分割する。`assignments` は個別付与行数、`overview` は集計対象文書数をページ件数の基準とする
- `assignments` のCSVはpage、active tab、RTPの列表示設定に依存せず、現在の検索条件に一致する個別付与行を全件出力する
- RTPの `table_key` は権限一覧を `admin_document_permissions`、文書別概要を `admin_document_permission_overview` とし、既存の保存設定との互換性を維持する
- tabはserver-rendered navigationとして扱い、active tabに対応するpanelだけを描画する
- 各tabの`aria-controls`は対応する固定panel IDを参照し、inactive tabがactive panel IDを参照しない。権限一覧は`document-permissions-assignments-panel`、文書別概要は`document-permissions-overview-panel`とする
- 選択中tabだけを`tabindex="0"`、他を`tabindex="-1"`とし、左右矢印・Home・Endはfocusだけを移動する。EnterまたはSpaceでfocus中のlinkを実行し、遷移後の選択状態はserver responseを正本にする

## 管理概要と運用・診断

- `/admin` は日常の一次確認画面とし、設定警告・実体欠落・継続失敗候補の件数、会社・ユーザー・案件・文書の主要件数、保存済み失敗履歴のうち直近最大5カテゴリだけを表示する
- `/admin` の見出しは他のAdmin画面と同じneutralな`管理概要`とし、HTMLの`header` tagだけを理由にdark PageHeaderを適用しない
- 管理概要のmetricは数字を最重要情報として表示し、0件を弱く、異常ありだけをwarning / dangerで強調する
- 設定診断は`/admin/diagnostics#configuration`、文書実体欠落は`#document-files`、継続失敗候補は`#failures`へ直接移動できるようにする
- 設定警告と運用失敗を混同しないよう、保存済み失敗履歴は`最近の運用失敗`等の名称で表示する
- `/admin` では設定診断の全check、Storage内訳、欠落ファイル行、model catalog全体、継続失敗候補のidentity・error preview・Markdown digestを表示しない
- `/admin/diagnostics` はinternal admin専用のread-only画面とし、要対応、運用失敗、設定診断、文書ファイル健全性、Storage、モデル観測の順に確認できるようにする
- Diagnostics最上部には各sectionへの短いnavを置き、モデル観測は最後に配置する。正常モデル全件を大量Card表示せず、件数・最終更新・Model Browser導線へ要約し、必要な正常項目だけDisclosureで確認する
- `READ_ONLY_MAINTENANCE` 中も管理概要と運用・診断の確認導線は維持し、再試行、再送、同期、削除、cleanupなどの変更操作を運用・診断画面へ追加しない
- `company_master_admin` は従来どおり自社管理用landingだけを利用し、`/admin/diagnostics` へはアクセスできない

## 画面状態のスクリーンショット検証

- `bin/all_test`のdesktop撮影では、`/documents`と`/admin/diagnostics`をcustom routeとして個別に撮影する
- 文書権限は`assignments`と`overview`、保存済みは`favorite`、`read_later`、`recent`をquery parameter付きURLから個別に撮影する
- 文書権限と保存済みのdefault index captureは、状態名付きcaptureとの重複を避ける
- 各状態は同じbasenameのPNG / HTMLを生成し、画面操作ガイドでcanonicalな日本語captionと操作説明へ対応付ける
- Screen Guideは生成物を直接編集せず、`script/generate_screen_docs.ts`のmetadataを変更して`bin/all_test`で再生成する
- `root`と`dashboard`が同じホームを表示する場合は、別Screenとして重複掲載しない
- mobile captureはこの検証対象に含めない

## 利用者ホーム

- ログイン後に `GET /dashboard` で利用者向けホームを表示できる
- ホームには、自分が閲覧可能な案件、お気に入り、後で読む、最近見た文書、最近更新された文書を表示する
- ホームには、案件数・文書数・保存済み件数・保留中申請数などのworkspace summaryを表示する
- workspace summaryは数字を`font-weight: 700`、`var(--ui-text)`程度で強調し、件数の定義や空状態の補足はTooltipまたは初期状態を閉じたDisclosureから確認できるようにする
- 一覧カードは内容量の異なる同一行でも不要に同じ高さへ引き伸ばさず、短いカードの下に大きな空白を作らない。Cardを増やさず、文書一覧のhover領域は行全体へ広げる
- 権限外文書はbookmarkや監査ログに存在しても表示しない

## Markdown preview / version diff

- 版詳細画面は、本文表示、添付、品質チェック、前版との差分確認へ迷わず移動できる preview hub として扱う
- 版詳細画面では、閲覧可能な直前の `DocumentVersion` と比較し、添付・元ファイルの追加、変更、削除件数を表示する
- 差分サマリは、保持済みファイルの `tree_path`、ファイルサイズ、content type、file name を使ったファイル単位の比較から始める
- Markdown本文の行単位diffは、 `.md` / `.markdown` の元ファイルを対象に、前版と新版の行差分として表示する
- Markdown本文の行単位diffでは、追加行、削除行、前後コンテキストを unified diff 風に表示する
- 大きすぎるMarkdownファイル、または元ファイルを読み込めない場合は、行単位diffを省略し、理由を利用者へ表示する
- レンダリング後HTML差分は、Docusaurus生成済みHTMLから表示テキストを抽出して表示する
- レンダリング後HTML差分では、script、style、nav、sidebar、footer などの viewer chrome を除外し、本文に近い変更だけを表示する
- HTML本文が未生成、大きすぎる、または読み込めない場合は、HTML差分を省略し、理由を利用者へ表示する
- HTML本文内の table は、表単位・セル単位でも差分を表示する
- 表セル差分では、表追加、表削除、セル追加、セル削除、セル変更を判定して表示する
- 表セル数が多すぎる場合は、表セル差分を省略し、理由を利用者へ表示する
- 差分ビューは Markdown差分、HTML差分、表セル差分へ移動できるタブ風ナビゲーションを持つ
- 差分ビューのタブ、各セクション、Markdownファイル、表ごとに変更件数バッジを表示する
- ブラウザ上でのMarkdown編集保存は後続実装とし、既存画面では preview / diff / 添付 / 品質チェックの閲覧導線を優先する
- 版詳細画面の hero、workspace 見出し、補助文言は Markdown 専用固定にせず、版種別に関わらず「版詳細の確認ハブ」であることが先に伝わる表現を優先する
- read-only の版詳細画面では、操作不能な編集風 toolbar や、押せないのに押せそうに見える control を置かない
- タブ風ナビゲーションや mode 切り替えを置く場合は、現在地表示か、実際に移動できる導線だけで構成する
- `添付・元ファイル` の分類表示は、internal key をそのまま見せず、利用者向けラベルと内部分類値を分ける

## Docusaurus viewer

- `source_relative_path` はMarkdown原本の相対path、`markdown_entry_path` は生成成果物へ到達できるpage route、`site_build_path` は版専用成果物のentry pathとして区別する。preview installerとartifactからの復旧で`markdown_entry_path`へ原本pathを再保存しない
- rootの `README.md` / `README.mdx` / `index.md` とその生成HTMLは `index` routeとして扱う。過去に生成されたroot Markdown名のsite URLも `index.html` への互換aliasとして解決する
- `GET /projects/:project_code/site/*site_path` および `GET /document_versions/:public_id/site/*site_path` の HTML 応答は、初期表示では viewer shell を返す
- viewer shell は Rails 側の header / breadcrumb / action を持ち、本文部分は same-origin iframe で読み込む
- viewer shell は、本文 iframe の上に preview toolbar を持ち、版詳細、前版との差分、添付・元ファイルへ戻れるようにする
- iframe 側の本文は `embedded=1` 付き同 route を使って取得する
- iframe 側では Docusaurus navbar / footer / toc / sidebar を除去し、本文を中央寄せで表示する
- iframe 側で rewrite される内部 link / asset URL も `embedded=1` を維持する
- viewer shell は same-origin iframe の本文高さに追従し、初期表示後や画像・遅延コンテンツ読込後に本文が伸びても二重スクロールを常態化させない
- embedded HTML 側は親 viewer へ本文高さを通知し、viewer shell 側は同一 origin の iframe にだけその高さ更新を反映する
- viewer shell は same-origin iframe 内の `h1` から `h3` までを収集し、最大 24 件の見出し移動ボタンとして表示できる
- 見出しがない場合、または iframe document を読めない場合でも viewer 表示は壊さず、見出しなし / 取得不可の状態表示に留める
- 見出し導線は本文内移動の補助であり、browser native search、table toolbar、codeblock toolbar、全文検索 index、server-side search とは別の機能として扱う
- viewer shell の hero、toolbar、aria label は portal 全体の表示言語に合わせ、利用者向け文言へそろえる
- viewer shell では、版詳細、差分、添付・元ファイル、品質などの戻り先を action / link として明示し、静的な疑似タブだけを残さない
- viewer shell の現在地表示をタブ風に見せる場合も、非アクティブ項目は link にするか plain な current-state 表示に留め、押下不能な control に見せない

## Docusaurus build profiles

- Docusaurus build は用途別 profile を持てるようにする
- build profile は、qaboard の Web アプリ埋め込み用 build と webdriverio の生成前処理・strict link check の考え方を docs-portal 向けに整理したものとして扱う
- build profile は `url`、`baseUrl`、`routeBasePath`、navbar / footer / sidebar の有無、broken link policy、前処理、出力先を切り替える
- build profile は環境変数または明示的な build command で選択し、暗黙の分岐を避ける

想定 profile:

| profile | 用途 | 主な違い |
| --- | --- | --- |
| `portal_embedded` | Rails viewer shell の iframe 内表示 | navbar / footer / toc / sidebar を最小化、same-origin route 前提、`embedded=1` 互換 |
| `standalone_public` | 将来の単体公開サイト | navbar / footer / search を有効化、canonical URL を外部公開向けに設定 |
| `admin_api_spec` | 管理画面のAPI仕様 | internal import API docs を生成前処理で更新、admin viewer に最適化 |
| `preview_check` | 標準文書テンプレート preview / apply 前確認 | strict link check、metadata validation、差分用 artifact 生成 |
| `diff_metadata` | 版差分・品質チェック補助 | HTML本文抽出、見出し一覧、table index、codeblock index などを生成 |

- `portal_embedded` では、Rails 側の viewer shell が navigation を担うため、Docusaurus 側の chrome は最小化する
- `standalone_public` では、Docusaurus 側の navbar、footer、search、version dropdown を有効化できるようにする
- `admin_api_spec` では、API仕様 Markdown の生成前処理を build 前に実行し、生成元が新しい場合は `BuildFreshnessGuard` で build job を enqueue する
- `preview_check` では、broken links、存在しない metadata path、旧 path 参照、通常表示ファイル0件などを警告またはエラーにする
- `diff_metadata` では、viewer runtime で重い解析を避けるため、見出し、code block、table、内部 link の index を生成できるようにする
- broken link policy は profile ごとに変える
  - internal preview は warning 中心
  - external publish / preview apply は error 中心
  - archived version は warning 中心
- build profile の出力には、profile 名、source commit、build time、Docusaurus version、validation result を manifest として保存する
- viewer shell は manifest を参照し、build profile 不一致や stale build を利用者へ表示できるようにする
- build profile は Project / DocumentVersion / API仕様などの利用箇所ごとに既定値を持てるようにする
- 将来的に複数 docs plugin / route 分割を導入する場合も、profile ごとに docs root と sidebar を選択できるようにする

## Codeblock actions

- Docusaurus viewer 内の code block には、内容や言語に応じて利用者向け action を付与できるようにする
- codeblock actions は、API仕様、手順書、運用マニュアル、import API のサンプルで使いやすさを上げるための viewer 拡張として扱う
- codeblock actions は Markdown 原文や生成済みHTMLを変更せず、viewer shell または iframe 内拡張として提供する
- codeblock actions は、コピーなどの即時操作と、dry-run / 検証などのサーバー連携操作を区別する
- サーバー連携操作は、権限判定、CSRF対策、実行前確認、結果表示、access log を必須とする
- サーバー連携操作は、既定では destructive な処理を実行せず、dry-run / validation から始める

想定 action:

| 対象 | action | 補足 |
| --- | --- | --- |
| `curl` | コピー | token や secret らしき値は mask された表示を優先する |
| `json` | JSONコピー / 整形コピー / validation | API request sample や metadata sample に使う |
| `yaml` / `yml` | YAMLコピー / validation | preview target metadata や workflow sample に使う |
| `bash` / `sh` | コマンドコピー | 複数行コマンドは1つの script としてコピーできる |
| `npm` / `yarn` / `pnpm` | package manager 切り替え | Docusaurus実例の npm/yarn切り替えに相当する |
| `http` | request sample コピー / dry-run | internal import API のサンプル検証に使う |
| `ruby` / `rails` | コマンドコピー | admin向け運用手順に使う |
| unknown | copy only | 言語不明でも最低限コピーは提供する |

- copy action はブラウザ clipboard API を使い、成功・失敗を code block 近くに表示する
- copy action は iframe が same-origin の場合に有効化し、cross-origin の場合は viewer 表示を壊さず無効化する
- secret、token、password、authorization header などを含む可能性がある code block は、自動実行や外部送信の対象にしない
- dry-run action は、対象 API・操作種別・入力内容・実行ユーザーを明示してから実行する
- dry-run 結果は、成功 / 警告 / エラーを code block 下に表示し、必要なら詳細ログを折りたたむ
- import API dry-run は、実際の文書更新を行わず、作成予定の Project / Document / DocumentVersion / DocumentFile の概要を返す
- codeblock action は、レビューコメントの anchor と連携できるように、code block id、言語、行番号を持てるようにする
- code block 内の特定行に対して internal review comment を付けられるようにする
- codeblock action の表示有無は、文書種別、利用者権限、code language、metadata に応じて制御できるようにする
- admin は API仕様ページの codeblock action を dry-run で検証できる
- external 利用者には copy 系 action を中心に表示し、server-side dry-run は必要な権限がある場合だけ表示する
- action 実行時には、対象文書版、site path、code block id、action kind、結果を access log または audit log に残せるようにする

## Path history / redirect

- 文書 slug、Docusaurus site path、添付・元ファイル tree path は、外部共有済みURLや社内bookmarkを壊さないため、履歴を持てるようにする
- path history は、現在の canonical path と過去の alias path を区別する
- 旧URLへアクセスした場合、閲覧権限を確認した上で canonical URL へ誘導する
- redirect は権限判定より前に情報を漏らしてはならない
- 権限がない旧URLでは、現在の文書名や移動先を表示せず、通常の権限エラーまたは申請導線を表示する
- canonical URL へ誘導できる場合は 301 ではなく、まずは 302 / 303 など安全な一時 redirect として扱う
- path history は、削除済み・アーカイブ済み・移動済みを区別する
- 移動済み文書では、viewer shell または文書詳細に「この文書は移動しました」という notice を出せるようにする
- アーカイブ済み文書では、最新版や後継文書がある場合に代替先を表示する
- 削除済み文書では、代替先が明示されている場合だけ案内し、それ以外は通常の not found とする

対象:

| 対象 | 例 | 履歴の用途 |
| --- | --- | --- |
| Document slug | `/projects/:project_code/documents/:slug` | 文書名変更・整理後も旧URLを維持する |
| Docusaurus site path | `/projects/:project_code/site/docs/old-page` | Markdown path / generated HTML path 変更後も旧URLから本文へ誘導する |
| DocumentVersion site path | `/document_versions/:public_id/site/docs/old-page` | 版ごとの生成済みHTML内リンクを壊しにくくする |
| DocumentFile tree path | `attachments/old/name.pdf` | 添付・元ファイルの移動やrename後も履歴・差分・metadataを追いやすくする |
| Catalog / Set item path | curated list item | 文書カタログや文書セットの旧参照を保つ |

- Document slug history は Project 内で一意に扱う
- Docusaurus site path history は Document または DocumentVersion の scope 内で一意に扱う
- DocumentFile tree path history は DocumentVersion 内で一意に扱う
- 新しい path が既存 alias と衝突する場合は保存時にエラーまたは品質チェック警告を出す
- path history は preview target metadata の `primary`、`attachments`、`hidden`、`debug`、`groups.paths` の解決にも使えるようにする
- metadata の path pattern が旧 path に一致する場合、品質チェックで canonical path への更新候補を出す
- 任意版比較では、tree path の変更を単純な削除・追加だけでなく、可能なら rename / moved として扱えるようにする
- access log は、アクセスされた元URLと解決後の canonical target の両方を記録できるようにする
- admin は slug / path 変更前に dry-run で影響範囲を確認できるようにする
- dry-run では、旧URL数、catalog / set 参照、preview target metadata、内部リンク、外部送付履歴への影響を表示する

## Markdown table viewer UX

- HTML viewer shell 内の Markdown table は、表ごとに viewer toolbar を付与し、横長・縦長の表を読みやすくする
- 表 toolbar の拡張は iframe 内の same-origin Docusaurus本文に対して行う
- iframe が将来 cross-origin になった場合でも、table toolbar 拡張に失敗して viewer 表示自体を壊してはならない
- 表幅は表ごとに調整できる
- 表幅は利用者のブラウザに保存し、同じ preview route を開き直しても調整後の幅を維持する
- Markdown table は列境界をドラッグして列幅も調整できる
- 列幅は利用者のブラウザに保存し、同じ preview route を開き直しても調整後の列幅を維持する
- 列幅はキーボードでも調整できるようにする
- 表ごとに先頭行固定を ON / OFF できる
- 表ごとに先頭列固定を ON / OFF できる
- 先頭行固定と先頭列固定は併用でき、左上セルの重なりが崩れないようにする
- 表ごとに表内検索ができる
- 表内検索では一致セルをハイライトし、検索中は一致しない行を折りたたむ
- 表内検索では一致件数を表示し、検索語をクリアできる
- 表ごとに CSV 形式でコピーできる
- 表ごとに Markdown table 形式でコピーできる
- コピー操作では成功・失敗の状態を利用者へ表示する
- 表ごとに表示設定をリセットできる
- 表示リセットでは、表幅、列幅、先頭行固定、先頭列固定の保存値を削除し、現在表示中の表も標準状態へ戻す
- 表 toolbar は、検索、表示、コピーのグループに分けて表示する
- モバイル幅では表 toolbar のグループが縦積みになり、操作が崩れないようにする
- 表幅、列幅、固定表示、検索、コピー、表示リセットはいずれも表示上の利用者個人設定・操作として扱い、Markdown 原文や生成済みHTMLは変更しない
- Markdown table tool の JavaScript は view template に直接長く埋め込まず、フロントエンドモジュールとして保守できるようにする

## DocumentFile viewer registry

- 添付・元ファイルの preview は、ファイル種別ごとの viewer registry で選択する
- viewer registry は、`DocumentFile` の content type、file extension、保持パス、外部同期 metadata、file size、viewer の利用可否を入力にして viewer を決める
- viewer registry は、利用者が閲覧可能なファイルだけを対象にする
- viewer registry は、ファイルを直接表示できない場合でも、理由と代替導線を利用者へ表示する
- viewer registry は、preview 成功・fallback・preview 不可・download only の状態を区別する
- viewer registry の判定は UI から直接分岐させず、サービスまたは presenter に集約する
- viewer registry は、新しい viewer を追加しても既存の添付一覧 UI を大きく変えずに済む構造にする

| 種別 | 主 viewer | fallback / 補足 |
| --- | --- | --- |
| Markdown (`.md`, `.markdown`) | Docusaurus HTML preview | 生成済みHTMLがない場合は source preview / download |
| HTML (`.html`) | same-origin iframe | unsafe / external HTML は download only |
| PDF | PDF preview | 大容量時は download only |
| Office (`.doc`, `.docx`, `.xls`, `.xlsx`, `.ppt`, `.pptx`) | Microsoft Graph preview | Google Drive sync由来なら Google Drive viewer fallback |
| CSV / TSV | table viewer | 大容量時は sample preview + download |
| JSON / YAML | code viewer / tree viewer | parse不能時は text viewer |
| Text / log | text viewer | 大容量時は head / tail preview + download |
| Image | image viewer | 大容量時は resized preview + download |
| ZIP / archive | archive tree | 展開不可時は download only |
| Unknown binary | download only | preview不可理由を表示 |

- Markdown viewer は、本文 preview、Markdown行diff、HTML差分、表セル差分と連携する
- HTML viewer は、Docusaurus viewer shell と同じ安全な iframe 表示方針に合わせる
- CSV / TSV viewer は、Markdown table viewer UX と同様に検索・コピー・幅調整などを再利用できる設計にする
- JSON / YAML viewer は、将来的に JSON path / YAML path ベースのレビューコメント位置指定と接続できるようにする
- Text / log viewer は、レビューや生成ログ確認のため、行番号表示と行への anchor を持てるようにする
- archive viewer は、ZIP内ファイルを tree view で表示し、個別ファイル preview に viewer registry を再適用できるようにする
- download 権限がない利用者には、download only viewer ではなく権限申請導線を表示する
- preview への遷移は、必要に応じて file view access log として記録する
- viewer registry は、将来の表示対象宣言 metadata と連携し、primary / attachment / hidden / debug などの見せ方を扱えるようにする

## Preview target metadata

- 文書版は、添付・元ファイルを利用者へどう見せるかを宣言する preview target metadata を持てるようにする
- preview target metadata は、qaboard の visualization 定義のように、表示対象、グループ、既定表示、非表示対象を宣言するための metadata として扱う
- preview target metadata は Markdown 原文や生成済みHTMLを直接変更せず、docs-portal 側の viewer / 添付一覧 / 文書セット表示を整理するために使う
- metadata がない文書版では、従来通り全ての閲覧可能な `DocumentFile` を tree path 順に表示する
- metadata に存在しないファイルも、権限があれば「その他」または元ファイル一覧から到達できるようにし、利用者がファイルを失わないようにする

例:

```yaml
preview:
  primary: docs/index.md
  attachments:
    - specs/*.pdf
    - tables/*.csv
  hidden:
    - debug/*
    - intermediate/*
  debug:
    - logs/*
    - generated/*.json
  groups:
    - name: API仕様
      description: 外部連携に必要な仕様書
      paths:
        - api/*.md
        - openapi/*.json
    - name: 参考資料
      paths:
        - references/*
```

- `primary` は文書版の主要 preview として扱う
- `attachments` は利用者へ通常表示する添付・元ファイルとして扱う
- `hidden` は通常の添付一覧では折りたたみ、必要に応じて表示できるようにする
- `debug` は社内向け・開発者向けの生成物やログとして扱い、既定では非表示にする
- `groups` は添付・元ファイル一覧や文書セット詳細での見出しとして使う
- `groups.paths` は glob 風の path pattern とし、保持済み `tree_path` に対して評価する
- `primary` / `attachments` / `hidden` / `debug` に指定されたファイルにも、最終的な表示可否は通常の権限判定を適用する
- metadata は viewer registry と連携し、各 path に対して適切な viewer を選択する
- metadata の不正な path pattern、存在しない path、重複指定は品質チェックで警告する
- metadata により通常表示されるファイルが0件になる場合は、品質チェックで警告する
- admin は標準文書テンプレートの preview / apply 前に、metadata による表示結果を dry-run で確認できる
- 将来的には Project / DocumentSet / DocumentVersion 単位で既定 metadata を上書きできるようにする

## Office file preview

- `.doc`, `.docx`, `.xls`, `.xlsx`, `.ppt`, `.pptx` は Office preview 対象とする
- Office preview は、まず案件ごとの `Microsoft Graph` 接続マスタを使う
- Microsoft Graph 接続が有効な場合、Rails は client credentials flow で access token を取得する
- Rails は対象ファイルを設定済み Drive のプレビュー用フォルダへ一時アップロードし、その driveItem に対して `/preview` を呼び出す
- Microsoft Graph 接続がない場合、または Graph の simple upload 制限を超える場合は、Google Drive 同期由来ファイルに限り Google Drive viewer へ fallback する
- Google Drive fallback は、`ExternalFolderSyncItem#external_item_id` と `provider_metadata.source_mime_type` から `drive.google.com/file/d/:id/preview` または `docs.google.com/.../:id/preview` を生成する
- Google Drive fallback は利用者ブラウザ側の Google アカウント権限に依存するため、ポータル上の閲覧権限だけでは表示できない場合がある
- Microsoft Graph 接続マスタには tenant ID、client ID、client secret、drive ID、プレビュー用フォルダを保存する
- client secret は暗号化カラムに保存する
- 250MBを超えるOffice fileは、Microsoft Graph へはアップロードしない。Google Drive fallback が使える場合は Google Drive viewer を優先し、使えない場合は iframe内に「プレビュー不可・ダウンロードのみ」の案内を表示する
- iframe には Rails の `document_files/:public_id?embedded=1` を読み込ませ、同 route から Graph の preview URL または Google Drive viewer URL へ redirect する
- Graph preview URL は一時 URL として扱い、DB に永続化しない
- Google Drive viewer URL は元ファイルIDから都度生成し、DBには永続化しない
- Office preview への遷移もファイル閲覧として access log を記録する
- Graph preview と Google Drive fallback のどちらも作成できない場合は 502 とし、通常のダウンロード導線は残す

## 危険操作の安全装置

- 危険操作に対して confirm と影響表示を優先する
- admin 画面の delete 操作は `turbo_confirm` 付きで実行する
- 変更前確認導線は、適用処理から分離した dry-run / preview として扱う

## DocumentReviewComment / Q&A

- `DocumentReviewComment` は internal review と公開 Q&A の共通 comment thread として使う
- コメント対象は `Document` と任意の `DocumentVersion` とする
- `internal_only = true` は社内レビュー、`false` は公開 Q&A thread として扱う
- root comment が `comment_type = question` かつ `internal_only = false` のものを Q&A thread として扱う
- external / company_master_admin / internal は、閲覧可能な文書または版の detail 画面から Q&A を投稿できる
- admin はレビューコメントの解決・却下を行える

## 文書カタログ

- `DocumentCatalog` は Project 配下の curated な文書一覧である
- route は `projects/:project_code/document_catalogs/:public_id` を使う
- 一覧では viewer が参照可能な catalog だけ表示する
- 詳細では viewer が参照可能な item だけ表示する

## 文書セット

- `DocumentSet` は Project 配下の用途別 document grouping である
- route は `projects/:project_code/document_sets/:public_id` を使う
- `admin` は管理画面から `DocumentSet` を作成・編集・削除できる
- `admin` は管理画面の `admin/document_sets` 一覧で `rails_table_preferences` ベースの表示設定 UI を開ける
- `admin/document_sets` 一覧の table preference key は `admin_document_sets` で固定する
- 一覧の表示設定 UI と table 本体は同じ `document_set_table_columns` を参照し、`project`、`name`、`set_type`、`visibility_policy`、`documents_count`、`actions` の各列を `data-rails-table-preferences-column-key` で対応付ける
- fixed version を指定しない item は、その `Document` の `latest_version` を使う

## AI向けコンテキスト生成

- Project 単位で AI 向けコンテキスト出力を取得できる
- viewer が参照可能な Document だけを対象にする
- HTML に加えて hash / markdown 形式でも同じ対象を出力できる

## 外部送付履歴

- 文書または文書セット単位で、外部送付の履歴を `DocumentDeliveryLog` として記録する
- 利用者は自分が作成した履歴を参照できる
- admin は全履歴を参照し、状態変更や確認を行える
