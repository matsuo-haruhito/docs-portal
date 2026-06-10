# フロントエンド初期化 inventory

この文書は、`doc/frontend_interaction_policy.md` の「Turbo -> Stimulus -> 素の JavaScript」の優先順位に沿って、current `main` の browser-side 初期化を棚卸しするための maintainer note です。

この first slice では structured / text preview helper を専用 Stimulus controller へ分離し、検索、clear、一致行のみ表示、copy、line anchor highlight、`/` / `Escape` shortcut の runtime behavior は変更しません。`document.addEventListener("keydown", ...)` と `window.addEventListener("hashchange", ...)` は controller の refresh / disconnect から cleanup できる形にし、Vite entrypoint の直接 DOM setup 回避、gem pinned ref、JSON / text preview rendering policy は変更しません。後続 issue を切るときに、どの初期化を維持し、どれを Stimulus / Turbo へ寄せるかを判断する入口として使います。

## 確認した入口

- `app/frontend/entrypoints/application.js`
  - CSS entrypoint と `@hotwired/turbo-rails` を読み込む。
  - Stimulus application を起動し、gem controller と app controller を明示登録する。
  - current code では `turbo:load` / `turbo:render` listener や `new TomSelect(...)` を entrypoint に直接置いていない。
- `app/frontend/controllers/*`
  - DOM に密着した小さな振る舞いを app 側 Stimulus controller に閉じ込めている。
  - 一部 controller は iframe や preview 内 DOM の再初期化のため、controller 内で document / window listener を持つ。
- `doc/frontend_interaction_policy.md`
  - app 側で手書き `new TomSelect(...)` を増やさず、RFK helper が出す `rails-fields-kit--tom-select` と gem controller を優先する方針を持つ。
  - Markdown preview table は current fallback path として `preview_table_resizer_controller.js` を使うと整理済み。

## Controller 登録の現状

### Gem 提供 controller

| 登録名 | 由来 | current role | 判断 |
| --- | --- | --- | --- |
| `rails-table-preferences` | `rails_table_preferences` | 通常の Rails 一覧 table の表示列、列幅、preset などを扱う | gem controller を優先して維持 |
| `rails-fields-kit--tom-select` | `rails_fields_kit` | RFK helper が出す searchable select / tag / autocomplete の Tom Select 初期化を扱う | app 側 `new TomSelect(...)` を増やさず維持 |

### App 側 controller

| 登録名 | 主な対象 | 初期化分類 | 次の判断 |
| --- | --- | --- | --- |
| `auto-height-frame` | embedded iframe の高さ同期 | iframe load、postMessage、ResizeObserver / MutationObserver | iframe 補助として維持。Turbo 化候補ではない |
| `bulk-edit-selection` | 文書一括編集候補の選択数・表示件数 | data-target 内の filter / count 更新 | app 側 Stimulus として維持 |
| `csv-preview-tools` | CSV preview table | `setupCsvPreviewTableTools()` を専用 controller から refresh する | `preview-tools` bridge から分離済み。CSV preview の table behavior / export contract は helper 側で維持 |
| `document-file-browser` | 版詳細の添付・元ファイル browser | kind / query filter と empty state | app 側 Stimulus として維持 |
| `document-file-list-search` | 添付・元ファイル list search | `setupDocumentFileListSearch()` を専用 controller から refresh する | `preview-tools` bridge から分離済み。query / clear / count / match highlight / parent context row 表示は helper 側で維持 |
| `document-permission-error-surface` | RFK remote picker の error surface | RFK controller からの event / detail を表示面へ反映 | RFK gem controller との接続面として維持 |
| `document-set-document-filter` | 文書セット対象文書候補 | local filter、selected-only、remote picker からの候補反映 | RFK remote picker との host-app 補助として維持 |
| `document-version-tabs` | 版詳細 tab | DOM 構造の panel 化、hashchange、keyboard tab 操作 | 既存 source spec があり、app 側 Stimulus として維持 |
| `document-zip-selection` | ZIP 出力対象選択 | page / matching / explicit scope の count 表示 | app 側 Stimulus として維持 |
| `nav-dropdowns` | header details dropdown | native `details` の開閉に、同時 open 抑止 / outside click close / Escape close だけを lifecycle 内 listener で補う | `spec/frontend/nav_dropdowns_contract_spec.rb` で current contract を guard 済み。CSS / native details だけへの置換はここでは先取りしない |
| `document-tree-navigation` | tree link click 後の Turbo Stream refresh | document click listener、`fetch(... Accept: text/vnd.turbo-stream.html)` | Turbo Stream 補助として維持。TreeView gem API へ押し戻さない |
| `file-dropzone` | form 内 file dropzone | dragenter / dragover / drop と filename 表示 | app 側 Stimulus として維持 |
| `manual-document-upload` | preview / tree 周辺の manual upload drop | window / iframe document drag listener、hidden multipart form submit | `spec/frontend/manual_document_upload_controller_source_spec.rb` で listener lifecycle と single-file submit flow を guard 済み。複数 file や API 変更は別 issue |
| `markdown-preview-document-search` | Markdown preview iframe 内検索 | `setupMarkdownPreviewDocumentSearch()` を専用 controller から refresh する | `preview-tools` bridge から分離済み。検索 UI の copy / keyboard / empty state は変更しない |
| `markdown-preview-codeblock-tools` | Markdown preview codeblock | `setupMarkdownPreviewCodeblockTools()` を専用 controller から refresh する | `preview-tools` bridge から分離済み。copy / JSON整形 copy / JSON検証 / 機密注意 / line anchor / iframe style injection は変更しない |
| `image-preview-tools` | image preview | `setupImagePreviewTools()` を専用 controller から refresh し、再描画時に button / keydown listener を cleanup する | `preview-tools` bridge から分離済み。fit / zoom / rotate / status / localStorage contract は変更しない |
| `pdf-preview-tools` | PDF preview | `setupPdfPreviewTools()` を専用 controller から refresh し、再描画 / disconnect 時に button / keydown listener を cleanup する | `preview-tools` bridge から分離済み。height toggle / status / `aria-pressed` / localStorage / keyboard shortcut contract は変更しない |
| `structured-preview-tools` | structured / text preview | `setupStructuredPreviewTools()` を専用 controller から refresh し、再描画 / disconnect 時に input / button / document keydown / hashchange listener を cleanup する | `preview-tools` bridge から分離済み。検索、clear、一致行のみ表示、copy、line anchor highlight、`/` / `Escape` shortcut は変更しない |
| `preview-table-resizer` | Markdown preview table | iframe 内 table wrapping、localStorage、column resize、`turbo:load` / `turbo:render` refresh | current fallback path として維持。列幅、列幅の保存、ヘッダー固定、先頭列固定に閉じ、RTP 統合判断は #475 に残す |
| `preview-tools` | preview 内 table / archive / iframe 補助 | Markdown codeblock / document file list / structured / PDF / image / CSV 以外の `setupXxx()` library を Stimulus controller から refresh する bridge | `spec/frontend/preview_tools_source_spec.rb` で helper bridge / Turbo lifecycle / entrypoint registration を guard 済み。document search、Markdown codeblock、document file list search、structured / text preview、CSV preview table、image preview、PDF preview は専用 controller へ分離済み。その他の個別 `setupXxx()` の Stimulus 化は別 issue |
| `sidebar` | 文書ツリー sidebar width / collapsed state | localStorage、pointer / keyboard resize | app 側 Stimulus として維持 |

## 素の JavaScript / listener の棚卸し

### Entry point 直書き

`app/frontend/entrypoints/application.js` には、controller 登録以外の直接 `querySelectorAll`、直接 event listener、直接 `new TomSelect(...)` は置かれていません。新しい UI でもこの状態を維持します。

### Controller 内の document / window listener

次の listener は controller lifecycle 内に閉じているため、現時点では許容される app 側 Stimulus 初期化です。

- `document-tree-navigation`: document click を拾って tree refresh 用 Turbo Stream を取得する。
- `nav-dropdowns`: native `details` dropdown の同時 open / outside click close / Escape close を同期する。click での開閉そのものは native `details` に任せる。`spec/frontend/nav_dropdowns_contract_spec.rb` が document listener の登録 / cleanup と one-open / outside-click / Escape の代表 signal を固定している。
- `manual-document-upload`: window と iframe document の drag event を拾い、既存 upload form flow へ渡す。`spec/frontend/manual_document_upload_controller_source_spec.rb` が listener の登録 / 解除、inaccessible iframe の no-op、single file hidden multipart form submit、複数 file 未対応の境界を固定している。
- `document-file-list-search`: 添付・元ファイル list search を Turbo 再描画後にも再探索する。既存 `setupDocumentFileListSearch()` helper を専用 controller から呼ぶだけで、query / clear / count / match highlight / parent context row 表示は変更しない。
- `markdown-preview-document-search`: preview iframe 内 document search を Turbo 再描画後にも再探索する。既存 `setupMarkdownPreviewDocumentSearch()` helper を専用 controller から呼ぶだけで、検索 UI の copy / keyboard / empty state は変更しない。
- `markdown-preview-codeblock-tools`: preview iframe 内 codeblock 補助を Turbo 再描画後にも再探索する。既存 `setupMarkdownPreviewCodeblockTools()` helper を専用 controller から呼ぶだけで、copy / JSON整形 copy / JSON検証 / 機密注意 / line anchor / iframe style injection は変更しない。
- `csv-preview-tools`: CSV preview table helper を Turbo 再描画後にも再探索する。既存 `setupCsvPreviewTableTools()` helper を専用 controller から呼ぶだけで、CSV table UI、copy、sticky state、column resize、export contract は変更しない。
- `image-preview-tools`: image preview helper を Turbo 再描画後にも再探索する。既存 `setupImagePreviewTools()` helper を専用 controller から呼び、再描画 / disconnect 時に button listener と document keydown listener を cleanup する。fit / zoom / rotate / status / localStorage contract は変更しない。
- `pdf-preview-tools`: PDF preview helper を Turbo 再描画後にも再探索する。既存 `setupPdfPreviewTools()` helper を専用 controller から呼び、再描画 / disconnect 時に height toggle click listener と document keydown listener を cleanup する。height toggle / status / `aria-pressed` / localStorage / `h` shortcut contract は変更しない。
- `structured-preview-tools`: structured / text preview helper を Turbo 再描画後にも再探索する。既存 `setupStructuredPreviewTools()` helper を専用 controller から呼び、再描画 / disconnect 時に input / button listener、document keydown listener、text preview の hashchange listener を cleanup する。検索、clear、一致行のみ表示、copy、line anchor highlight、`/` / `Escape` shortcut の runtime behavior は変更しない。
- `preview-table-resizer`: iframe preview table を Turbo 再描画後にも再探索する。
- `preview-tools`: Markdown codeblock / document file list / structured / PDF / image / CSV 以外の preview helper library の `setupXxx()` を Turbo 再描画後にも再実行する。document search、Markdown codeblock、document file list search、structured / text preview、CSV preview table、image preview、PDF preview は専用 controller へ分離済みで、`spec/frontend/preview_tools_source_spec.rb` が import する helper set、refresh 呼び出し順、Turbo listener の登録 / 解除、entrypoint に直接 DOM setup を置かない境界を固定している。
- `document-version-tabs`: hashchange に追従して tab panel を切り替える。

## Preview-tools helper bridge 分類

`preview-tools` は、preview iframe や生成済み preview DOM の補助 UI をまとめて再実行する bridge です。今回の分類は次の実装 issue を切るための棚卸しであり、helper 呼び出し順や runtime behavior は変更しません。document search は専用 `markdown-preview-document-search` controller へ分離済みです。Markdown preview codeblock は専用 `markdown-preview-codeblock-tools` controller へ分離済みです。document file list search は専用 `document-file-list-search` controller へ分離済みです。structured / text preview は専用 `structured-preview-tools` controller へ分離済みです。CSV preview table は専用 `csv-preview-tools` controller へ分離済みです。image preview は専用 `image-preview-tools` controller へ分離済みです。PDF preview は専用 `pdf-preview-tools` controller へ分離済みです。

| helper | preview 種別 | 主な DOM / Turbo 依存 | 分割判断 | 追加 guard 候補 |
| --- | --- | --- | --- | --- |
| `setupSiteViewerIframeHeightSync` | Docusaurus / site viewer iframe | iframe load / postMessage 系の高さ同期。Turbo 再描画後に iframe を再探索する | bridge 維持。preview 種別横断の iframe 補助で、個別 preview controller へ寄せない | iframe helper が refresh 先頭で走ること |
| `setupMarkdownPreviewTableTools` | Markdown preview table | preview table DOM、table search、copy / export、既存 preference path と `preview-table-resizer` fallback path との境界 | bridge 維持。#475 / RTP 統合判断前に分割せず、current fallback support を過大に書かない | Markdown table helper が bridge に残ること。RTP full integration を実装済みとして書かないこと |
| `setupArchivePreviewTools` | archive preview | ZIP / archive entry list の DOM 補助 | bridge 維持。download / unsafe path 境界と近いため UI redesign と混ぜない | archive helper が unsafe-path policy を先取りしないこと |

Source-level guard では、上の helper 名が docs の分類表・controller import・`refresh()` 呼び出しに揃っていることだけを固定します。分類表は candidate 判断の入口であり、追加の個別 Stimulus controller 実装、helper 削除、Docusaurus renderer / Markdown table 方針変更は別 issue で扱います。

## Source-level guard 済みの controller

| controller | guard file | guard している境界 | guard していないこと |
| --- | --- | --- | --- |
| `csv-preview-tools` | `spec/frontend/preview_tools_source_spec.rb` | helper import、Turbo 再描画後の再実行、entrypoint registration、preview-tools bridge からの分離 | CSV preview UI の redesign、table behavior / export contract の変更 |
| `document-file-list-search` | `spec/frontend/preview_tools_source_spec.rb` | helper import、Turbo 再描画後の再実行、entrypoint registration、preview-tools bridge からの分離、count / parent context row guard の維持 | document file list search UI の redesign、`document-file-browser` 統合、query / clear / count / match highlight / parent context row behavior の変更 |
| `image-preview-tools` | `spec/frontend/preview_tools_source_spec.rb` | helper import、Turbo 再描画後の再実行、entrypoint registration、preview-tools bridge からの分離、listener cleanup 呼び出し | image preview UI の redesign、fit / zoom / rotate / status / localStorage contract の変更 |
| `pdf-preview-tools` | `spec/frontend/preview_tools_source_spec.rb` | helper import、Turbo 再描画後の再実行、entrypoint registration、preview-tools bridge からの分離、listener cleanup 呼び出し | PDF preview UI の redesign、height toggle / status / `aria-pressed` / localStorage / keyboard shortcut contract の変更 |
| `structured-preview-tools` | `spec/frontend/preview_tools_source_spec.rb` | helper import、Turbo 再描画後の再実行、entrypoint registration、preview-tools bridge からの分離、document keydown / hashchange listener cleanup 呼び出し | structured / text preview UI の redesign、JSON / text preview rendering policy、search / filter / copy / line anchor / keyboard shortcut behavior の変更 |
| `markdown-preview-codeblock-tools` | `spec/frontend/preview_tools_source_spec.rb` | helper import、Turbo 再描画後の再実行、entrypoint registration、preview-tools bridge からの分離、iframe style / toolbar / warning / line anchor guard の維持 | codeblock toolbar redesign、JSON / copy / warning / line anchor behavior の変更 |
| `markdown-preview-document-search` | `spec/frontend/preview_tools_source_spec.rb` | helper import、Turbo 再描画後の再実行、entrypoint registration、preview-tools bridge からの分離 | document search UI の redesign、検索 copy / keyboard / empty state の変更 |
| `preview-tools` | `spec/frontend/preview_tools_source_spec.rb` | helper bridge set、docs 上の helper 分類表、`refresh()` の呼び出し順、Turbo 再描画後の再実行、entrypoint 直書き DOM setup 回避 | document search / Markdown codeblock / document file list / structured / CSV / image / PDF 以外の helper 群の Stimulus 分割、preview UI redesign、#475 の Markdown table 方針 |
| `nav-dropdowns` | `spec/frontend/nav_dropdowns_contract_spec.rb` | controller registration、`details` markup、document listener cleanup、同時 open 抑止 / outside click / Escape close | controller 削除、navbar 情報設計、menu item / role 導線変更 |
| `manual-document-upload` | `spec/frontend/manual_document_upload_controller_source_spec.rb` | window / iframe document listener lifecycle、missing / inaccessible iframe no-op、single-file hidden form submit、複数 file 未対応 | 複数 file upload、upload API 化、manual upload review / apply contract、iframe preview redesign |

## 維持する fallback path

### Markdown preview table

`preview_table_resizer_controller.js` と `setupMarkdownPreviewTableTools` は、Docusaurus 生成 HTML table を Rails helper 経由で `rails_table_preferences` に接続していない current support の fallback path です。

current fallback support として提供していること:

- iframe 内の Markdown table wrapping、横スクロール、列幅調整、ヘッダー固定、先頭列固定。
- table search、copy、CSV / Markdown export、表示設定の reset。
- 既存の `/rails_table_preferences/preferences` path と `railsTablePreferencesTableKey` を使う default preference 補助。
- preview context key と table index に基づく localStorage の幅・sticky 表示補助。

#475 に残すこと:

- Markdown 由来 table を通常の `rails-table-preferences` controller に full 接続するかどうかの判断。
- column visibility / preset UI の本格統合、host app policy と埋め込み preview policy の整理。
- Docusaurus renderer や Markdown table DOM rewrite、preference schema / key の再設計。
- gem pinned ref、upstream gem API、Rails helper 側の table contract 変更。

維持する理由:

- `doc/frontend_interaction_policy.md` が app 側 preview tool として明示している。
- `spec/frontend/preview_table_resizer_source_spec.rb` が stable key と preview context marker を source-level に固定している。
- #475 は Markdown table を今後どこまで `rails_table_preferences` に寄せるかの親論点で、current support として先取りしない。

## 後続 issue に分ける候補

- `preview-tools` が呼ぶ `setupXxx()` library 群を、preview 種別ごとに Stimulus controller へ分けるか検討する。現時点では document search、Markdown codeblock、document file list search、structured / text preview、CSV preview table、image preview、PDF preview が専用 controller へ分離済みで、その他の bridge helper set と docs 分類表は source-level guard 済みです。
- `nav-dropdowns` は native `details` の開閉を活かしつつ、同時 open / outside click close / Escape close の current contract を app 側 controller で維持する。CSS / native details だけへ寄せる判断は、current contract を落とさない代替案が出たときに別 issue で扱う。
- `manual-document-upload` の複数 file upload、upload API 化、iframe preview UI redesign は、source guard 済みの single-file hidden form submit flow とは分けて扱う。
- Markdown preview table を `rails_table_preferences` へ寄せる判断は #475 に残し、この inventory では実装しない。
- internal UI gem pinned ref bump は #858 child issue 群に残し、この inventory では実装しない。

## この inventory の境界

- structured / text preview の search / filter / copy / line anchor highlight / `/` focus / `Escape` clear behavior は変更しない。
- document file list search の query / clear / count / match highlight / parent context row 表示 behavior は変更しない。
- `document-file-browser` controller の kind / query filter / empty state とは統合しない。
- Markdown preview codeblock の copy / JSON整形 copy / JSON検証 / 機密注意 / line anchor / iframe style injection behavior は変更しない。
- Markdown preview table の full `rails_table_preferences` 統合、column visibility / preset UI、Docusaurus renderer、DOM rewrite、preference schema / key 再設計は変更しない。
- PDF preview の height toggle / status / `aria-pressed` / localStorage / keyboard shortcut behavior は変更しない。
- image preview の fit / zoom / rotate / status / localStorage behavior は変更しない。
- `application.js` の直接 DOM setup は追加しない。
- app 側 `new TomSelect(...)` は追加しない。
- `rails_fields_kit` / `rails_table_preferences` / `tree_view` の public API、package export、pinned ref は変更しない。
- screen-by-screen adoption や UI redesign は #607 以降の個別 issue で扱う。
