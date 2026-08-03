# フロントエンド初期化 inventory

この文書は、`doc/frontend_interaction_policy.md` の「Turbo -> Stimulus -> 素の JavaScript」の優先順位に沿って、current `main` の browser-side 初期化を棚卸しするための maintainer note です。

この slice では Markdown preview table helper を専用 Stimulus controller へ分離し、table search、copy、CSV / Markdown export、preference path、preview context key、localStorage 幅補助、sticky fallback の挙動は変更しません。`preview-tools` bridge は空 bridge を残さず退役させます。#475 の full `rails_table_preferences` 統合、column visibility / preset UI、Docusaurus renderer、Markdown table DOM rewrite、preference schema / key 再設計は引き続き別判断として残します。

## 確認した入口

- `app/frontend/entrypoints/application.js`
  - CSS entrypoint と `@hotwired/turbo-rails` を読み込む。
  - Stimulus application を起動し、gem controller と app controller を明示登録する。
  - current code では `turbo:load` / `turbo:render` listener や `new TomSelect(...)` を entrypoint に直接置いていない。
  - `preview-tools` は登録せず、Markdown preview table は `markdown-preview-table-tools` を登録する。
- `app/views/layouts/application.html.slim`
  - preview 系 controller を `body[data-controller]` にまとめて attach する。
  - Markdown preview table は `markdown-preview-table-tools` を attach し、`preview-tools` は attach しない。
- `app/frontend/controllers/*`
  - DOM に密着した小さな振る舞いを app 側 Stimulus controller に閉じ込めている。
  - 一部 controller は iframe や preview 内 DOM の再初期化のため、controller 内で document / window listener を持つ。
- `doc/frontend_interaction_policy.md`
  - app 側で手書き `new TomSelect(...)` を増やさず、RFK helper が出す `rails-fields-kit--tom-select` と gem controller を優先する方針を持つ。
  - Markdown preview table は current fallback path として `preview_table_resizer_controller.js` と Markdown table helper を使うが、helper refresh は専用 controller に閉じる。

## Controller 登録の現状

### Gem 提供 controller

| 登録名 | 由来 | current role | 判断 |
| --- | --- | --- | --- |
| `rails-table-preferences` | `rails_table_preferences` | 通常の Rails 一覧 table の表示列、列幅、preset などを扱う | gem controller を優先して維持 |
| `rails-fields-kit--tom-select` | `rails_fields_kit` | RFK helper が出す searchable select / tag / autocomplete の Tom Select 初期化を扱う | app 側 `new TomSelect(...)` を増やさず維持 |

### App 側 controller

| 登録名 | 主な対象 | 初期化分類 | 次の判断 |
| --- | --- | --- | --- |
| `api-specification-codeblock-dry-run` | API仕様 viewer iframe の http codeblock | same-origin iframe 内 style injection、実行前 confirmation、dry-run endpoint fetch、結果表示 | admin_api_specification / http codeblock 限定で維持。apply / import / 外部 API 送信、generated HTML 永続変更、JSON/YAML validation は追加しない |
| `archive-preview-tools` | archive preview | `setupArchivePreviewTools()` を専用 controller から refresh する | `preview-tools` bridge から分離済み。download candidate、safe/unsafe path、visible rows、filter chips、copy status、sort/count behavior は helper 側で維持 |
| `auto-height-frame` | embedded iframe の高さ同期 | iframe load、postMessage、ResizeObserver / MutationObserver | iframe 補助として維持。Turbo 化候補ではない |
| `bulk-edit-selection` | 文書一括編集候補の選択数・表示件数 | data-target 内の filter / count 更新 | app 側 Stimulus として維持 |
| `company-master-admin-handoff` | company_master_admin landing の依頼テンプレート | clipboard copy button と status feedback | 権限、依頼先 URL、ticket/chat/mail 連携は増やさず、manual selection fallback を残す |
| `csv-preview-tools` | CSV preview table | `setupCsvPreviewTableTools()` を専用 controller から refresh する | `preview-tools` bridge から分離済み。CSV preview の table behavior / export contract は helper 側で維持 |
| `document-file-browser` | 版詳細の添付・元ファイル browser | kind / query filter と empty state | app 側 Stimulus として維持 |
| `document-file-list-search` | 添付・元ファイル list search | `setupDocumentFileListSearch()` を専用 controller から refresh する | `preview-tools` bridge から分離済み。query / clear / count / match highlight / parent context row 表示は helper 側で維持 |
| `document-permission-error-surface` | RFK remote picker の error surface | RFK controller からの event / detail を表示面へ反映 | RFK gem controller との接続面として維持 |
| `document-set-document-filter` | 文書セット対象文書候補 | local filter、selected-only、remote picker からの候補反映 | RFK remote picker との host-app 補助として維持 |
| `document-version-tabs` | 版詳細 tab | DOM 構造の panel 化、hashchange、keyboard tab 操作 | 既存 source spec があり、app 側 Stimulus として維持 |
| `document-zip-selection` | ZIP 出力対象選択 | page / matching / explicit scope の count 表示 | app 側 Stimulus として維持 |
| `nav-dropdowns` | header details dropdown | native `details` の開閉に、同時 open 抑止 / outside click close / Escape close だけを lifecycle 内 listener で補う | `spec/frontend/nav_dropdowns_contract_spec.rb` で current contract を guard 済み |
| `document-tree-navigation` | tree link click 後の Turbo Stream refresh | document click listener、`fetch(... Accept: text/vnd.turbo-stream.html)` | Turbo Stream 補助として維持。TreeView gem API へ押し戻さない |
| `file-dropzone` | form 内 file dropzone | dragenter / dragover / drop と filename 表示 | app 側 Stimulus として維持 |
| `manual-document-upload` | preview / tree 周辺の manual upload drop | window / iframe document drag listener、hidden multipart form submit | `spec/frontend/manual_document_upload_controller_source_spec.rb` で listener lifecycle と single-file submit flow を guard 済み |
| `markdown-preview-document-search` | Markdown preview iframe 内検索 | `setupMarkdownPreviewDocumentSearch()` を専用 controller から refresh する | `preview-tools` bridge から分離済み。検索 UI の copy / keyboard / empty state は変更しない |
| `markdown-preview-codeblock-tools` | Markdown preview codeblock | `setupMarkdownPreviewCodeblockTools()` を専用 controller から refresh する | `preview-tools` bridge から分離済み。copy / JSON整形 copy / JSON検証 / 機密注意 / line anchor / iframe style injection は変更しない |
| `markdown-preview-table-tools` | Markdown preview table | `setupMarkdownPreviewTableTools()` を専用 controller から refresh する | `preview-tools` bridge から分離済み。table search、copy、CSV / Markdown export、preference path、preview context key、localStorage 幅補助、sticky fallback は helper 側で維持 |
| `image-preview-tools` | image preview | `setupImagePreviewTools()` を専用 controller から refresh し、再描画時に button / keydown listener を cleanup する | `preview-tools` bridge から分離済み。fit / zoom / rotate / status / localStorage contract は変更しない |
| `pdf-preview-tools` | PDF preview | `setupPdfPreviewTools()` を専用 controller から refresh し、再描画 / disconnect 時に button / keydown listener を cleanup する | `preview-tools` bridge から分離済み。height toggle / status / `aria-pressed` / localStorage / keyboard shortcut contract は変更しない |
| `structured-preview-tools` | structured / text preview | `setupStructuredPreviewTools()` を専用 controller から refresh し、再描画 / disconnect 時に input / button / document keydown / hashchange listener を cleanup する | `preview-tools` bridge から分離済み。検索、clear、一致行のみ表示、copy、line anchor highlight、`/` / `Escape` shortcut は変更しない |
| `text-preview-tools` | text preview | hashchange と初期表示時の line anchor target cue を同期する | target row の `aria-current="location"` と blue cue を source-level に固定し、search match cue、copy、filter、toolbar、hashchange contract は変更しない |
| `preview-table-resizer` | Markdown preview table | iframe 内 table wrapping、localStorage、column resize、`turbo:load` / `turbo:render` refresh | current fallback path として維持。`表ツール` summary の横スクロール・列幅調整 cue、横スクロール領域の `aria-label`、列幅、列幅の保存、ヘッダー固定、先頭列固定に閉じ、RTP 統合判断は #475 に残す |
| `sidebar` | 文書ツリー sidebar width / collapsed state | localStorage、pointer / keyboard resize | app 側 Stimulus として維持 |
| `site-viewer-iframe-height` | Docusaurus / site viewer iframe | `setupSiteViewerIframeHeightSync()` を専用 controller から refresh する | `preview-tools` bridge から分離済み。same-origin check、message type、frame source check、minimum height、`data-docs-portal-auto-height` marker は helper 側で維持 |

## 素の JavaScript / listener の棚卸し

### Entry point 直書き

`app/frontend/entrypoints/application.js` には、controller 登録以外の直接 `querySelectorAll`、直接 event listener、直接 `new TomSelect(...)` は置かれていません。新しい UI でもこの状態を維持します。

### Controller 内の document / window listener

次の listener は controller lifecycle 内に閉じているため、現時点では許容される app 側 Stimulus 初期化です。

- `api-specification-codeblock-dry-run`: API仕様 iframe 内の http codeblock を表示時だけ装飾し、dry-run validation panel と結果表示を差し込む。
- `archive-preview-tools`: archive preview helper を Turbo 再描画後にも再探索する。
- `document-tree-navigation`: document click を拾って tree refresh 用 Turbo Stream を取得する。
- `nav-dropdowns`: native `details` dropdown の同時 open / outside click close / Escape close を同期する。
- `manual-document-upload`: window と iframe document の drag event を拾い、既存 upload form flow へ渡す。
- `document-file-list-search`: 添付・元ファイル list search を Turbo 再描画後にも再探索する。
- `markdown-preview-document-search`: preview iframe 内 document search を Turbo 再描画後にも再探索する。
- `markdown-preview-codeblock-tools`: preview iframe 内 codeblock 補助を Turbo 再描画後にも再探索する。
- `markdown-preview-table-tools`: Markdown preview table helper を Turbo 再描画後にも再探索する。既存 `setupMarkdownPreviewTableTools()` helper を専用 controller から呼ぶだけで、table search、copy、CSV / Markdown export、preference path、preview context key、localStorage 幅補助、sticky fallback は変更しない。
- `csv-preview-tools`: CSV preview table helper を Turbo 再描画後にも再探索する。
- `image-preview-tools`: image preview helper を Turbo 再描画後にも再探索する。
- `pdf-preview-tools`: PDF preview helper を Turbo 再描画後にも再探索する。
- `structured-preview-tools`: structured / text preview helper を Turbo 再描画後にも再探索する。
- `text-preview-tools`: text preview の location hash と line row を同期し、target cue と `aria-current="location"` を controller lifecycle 内の hashchange listener で更新する。
- `preview-table-resizer`: iframe preview table を Turbo 再描画後にも再探索する。
- `site-viewer-iframe-height`: site viewer iframe height sync を Turbo 再描画後にも再探索する。
- `document-version-tabs`: hashchange に追従して tab panel を切り替える。

## Preview-tools bridge の扱い

`preview-tools` bridge は、preview iframe や生成済み preview DOM の補助 UI をまとめて再実行する移行用 controller でした。document search、Markdown codeblock、document file list search、structured / text preview、CSV preview table、image preview、PDF preview、archive preview、site viewer iframe height sync に続き、Markdown preview table も専用 `markdown-preview-table-tools` controller へ分離済みです。

そのため current code では、空 bridge を残さず次を満たします。

- `app/frontend/controllers/preview_tools_controller.js` は存在しない。
- `app/frontend/entrypoints/application.js` は `preview-tools` を登録しない。
- `app/views/layouts/application.html.slim` は `preview-tools` を attach しない。
- Source-level guard は `spec/frontend/preview_tools_source_spec.rb` で、Markdown table helper の専用 controller 化、entrypoint / layout 登録、helper 本体の preference path 境界を確認する。

## Source-level guard 済みの controller

| controller | guard file | guard している境界 | guard していないこと |
| --- | --- | --- | --- |
| `api-specification-codeblock-dry-run` | `spec/requests/admin_api_specification_codeblock_dry_runs_spec.rb` | endpoint / admin-only / http codeblock hook / confirmation copy / no destructive send boundary | JSON/YAML validation、AccessLog enum expansion、generated HTML persistence、external API send |
| `archive-preview-tools` | `spec/frontend/preview_tools_source_spec.rb` | helper import、Turbo 再描画後の再実行、entrypoint registration、archive safety / candidate / visible row guard の維持 | archive preview UI redesign、ZIP / archive download safety、server-side route/controller contract の変更 |
| `csv-preview-tools` | `spec/frontend/preview_tools_source_spec.rb` | helper import、Turbo 再描画後の再実行、entrypoint registration | CSV preview UI の redesign、table behavior / export contract の変更 |
| `document-file-list-search` | `spec/frontend/preview_tools_source_spec.rb` | helper import、Turbo 再描画後の再実行、entrypoint registration、count / parent context row guard の維持 | document file list search UI の redesign、query / clear / count / match highlight / parent context row behavior の変更 |
| `document-file-browser` | `spec/frontend/document_file_browser_controller_source_spec.rb` | target set、initialization、kind / query filter、section / item search、status text、empty state、entrypoint registration | 版詳細の添付・元ファイル browser UI redesign、search ranking / highlight / pagination、Rails backend / route / preview / download contract の変更 |
| `image-preview-tools` | `spec/frontend/preview_tools_source_spec.rb` | helper import、Turbo 再描画後の再実行、entrypoint registration、listener cleanup 呼び出し | image preview UI の redesign、fit / zoom / rotate / status / localStorage contract の変更 |
| `pdf-preview-tools` | `spec/frontend/preview_tools_source_spec.rb` | helper import、Turbo 再描画後の再実行、entrypoint registration、listener cleanup 呼び出し | PDF preview UI の redesign、height toggle / status / `aria-pressed` / localStorage / keyboard shortcut の変更 |
| `structured-preview-tools` | `spec/frontend/preview_tools_source_spec.rb` | helper import、Turbo 再描画後の再実行、entrypoint registration、document keydown / hashchange listener cleanup 呼び出し | structured / text preview UI の redesign、search / filter / copy / line anchor / keyboard shortcut behavior の変更 |
| `text-preview-tools` | `spec/frontend/text_preview_tools_controller.test.mjs` | line anchor target row の `aria-current="location"`、target cue と search match cue の分離、entrypoint registration、view hook | text preview toolbar redesign、search / filter / copy behavior、line anchor id policy、hashchange contract の変更 |
| `markdown-preview-codeblock-tools` | `spec/frontend/preview_tools_source_spec.rb` | helper import、Turbo 再描画後の再実行、entrypoint registration、iframe style / toolbar / warning / line anchor guard の維持 | codeblock toolbar redesign、JSON / copy / warning / line anchor behavior の変更 |
| `markdown-preview-document-search` | `spec/frontend/preview_tools_source_spec.rb` | helper import、Turbo 再描画後の再実行、entrypoint registration | document search UI の redesign、検索 copy / keyboard / empty state の変更 |
| `markdown-preview-table-tools` | `spec/frontend/preview_tools_source_spec.rb` | helper import、Turbo 再描画後の再実行、entrypoint registration、旧 `preview-tools` bridge からの分離、preference path / table key guard の維持 | Markdown table helper の挙動変更、preview UI redesign、#475 の Markdown table 方針 |
| `site-viewer-iframe-height` | `spec/frontend/preview_tools_source_spec.rb`, `spec/frontend/site_viewer_iframe_height_source_spec.rb` | helper import、Turbo 再描画後の再実行、entrypoint registration、same-origin / message type / frame target guard の維持 | Docusaurus renderer、iframe rendering policy、postMessage protocol、auto height UI の redesign |
| `nav-dropdowns` | `spec/frontend/nav_dropdowns_contract_spec.rb` | controller registration、`details` markup、document listener cleanup、同時 open 抑止 / outside-click / Escape close | controller 削除、navbar 情報設計、menu item / role 導線変更 |
| `manual-document-upload` | `spec/frontend/manual_document_upload_controller_source_spec.rb` | window / iframe document listener lifecycle、missing / inaccessible iframe no-op、single-file hidden form submit、複数 file 未対応 | 複数 file upload、upload API 化、manual upload review / apply contract、iframe preview redesign |
| `preview-table-resizer` | `spec/frontend/preview_table_resizer_source_spec.rb` | preview context key、URL fallback、`表ツール` summary の横スクロール・列幅調整 cue、横スクロール領域の `aria-label`、embedded site response の context marker | Markdown table full RTP integration、column visibility / preset UI、Docusaurus renderer、preference schema / key 再設計 |

## 維持する fallback path

### Markdown preview table

`preview_table_resizer_controller.js` と `setupMarkdownPreviewTableTools` は、Docusaurus 生成 HTML table を Rails helper 経由で `rails_table_preferences` に接続していない current support の fallback path です。helper refresh は専用 `markdown-preview-table-tools` controller が担当します。

current fallback support として提供していること:

- iframe 内の Markdown table wrapping、横スクロール、列幅調整、ヘッダー固定、先頭列固定。
- 折りたたみ状態の `表ツール` summary からも読める `横スクロール・列幅調整できます` cue と、横スクロール領域の `aria-label` による読み取り補助。
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
- `spec/frontend/preview_table_resizer_source_spec.rb` が stable key、preview context marker、軽量な横スクロール・列幅調整 cue を source-level に固定している。
- #475 は Markdown table を今後どこまで `rails_table_preferences` に寄せるかの親論点で、current support として先取りしない。

## 後続 issue に分ける候補

- Markdown preview table を `rails_table_preferences` へ寄せる判断は #475 に残し、この inventory では実装しない。
- `nav-dropdowns` は native `details` の開閉を活かしつつ、同時 open / outside click close / Escape close の current contract を app 側 controller で維持する。
- `manual-document-upload` の複数 file upload、upload API 化、iframe preview UI redesign は、source guard 済みの single-file hidden form submit flow とは分けて扱う。
- internal UI gem pinned ref bump は #858 child issue 群に残し、この inventory では実装しない。

## この inventory の境界

- API仕様 codeblock dry-run は admin_api_specification / http codeblock / path-only internal API sample に限定し、apply / import / 外部 API 送信、generated HTML 永続変更、JSON / YAML validation は変更しない。
- archive preview の download candidate、safe/unsafe path、visible rows、filter chips、copy status、sort/count behavior は変更しない。
- site viewer iframe height sync の postMessage protocol、same-origin check、frame source check、minimum height は変更しない。
- structured / text preview の search / filter / copy / line anchor highlight / `/` focus / `Escape` clear behavior は変更しない。
- text preview の target cue と search match cue は分離して維持し、toolbar redesign、search / filter / copy behavior、line anchor id policy、hashchange contract は変更しない。
- document file list search の query / clear / count / match highlight / parent context row 表示 behavior は変更しない。
- `document-file-browser` controller の kind / query filter / empty state とは統合しない。
- Markdown preview codeblock の copy / JSON整形 copy / JSON検証 / 機密注意 / line anchor / iframe style injection behavior は変更しない。
- Markdown preview table の full `rails_table_preferences` 統合、column visibility / preset UI、Docusaurus renderer、DOM rewrite、preference schema / key 再設計は変更しない。
- PDF preview の height toggle / status / `aria-pressed` / localStorage behavior は変更しない。
- image preview の fit / zoom / rotate / status / localStorage behavior は変更しない。
- `application.js` の直接 DOM setup は追加しない。
- app 側 `new TomSelect(...)` は追加しない。
- `rails_fields_kit` / `rails_table_preferences` / `tree_view` の public API、package export、pinned ref は変更しない。
- screen-by-screen adoption や UI redesign は #607 以降の個別 issue で扱う。
