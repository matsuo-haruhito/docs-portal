# フロントエンド初期化 inventory

この文書は、`doc/frontend_interaction_policy.md` の「Turbo -> Stimulus -> 素の JavaScript」の優先順位に沿って、current `main` の browser-side 初期化を棚卸しするための maintainer note です。

この first slice では runtime behavior、Vite entrypoint、Stimulus controller registration、gem pinned ref は変更しません。後続 issue を切るときに、どの初期化を維持し、どれを Stimulus / Turbo へ寄せるかを判断する入口として使います。

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
| `document-file-browser` | 版詳細の添付・元ファイル browser | kind / query filter と empty state | app 側 Stimulus として維持 |
| `document-permission-error-surface` | RFK remote picker の error surface | RFK controller からの event / detail を表示面へ反映 | RFK gem controller との接続面として維持 |
| `document-set-document-filter` | 文書セット対象文書候補 | local filter、selected-only、remote picker からの候補反映 | RFK remote picker との host-app 補助として維持 |
| `document-version-tabs` | 版詳細 tab | DOM 構造の panel 化、hashchange、keyboard tab 操作 | 既存 source spec があり、app 側 Stimulus として維持 |
| `document-zip-selection` | ZIP 出力対象選択 | page / matching / explicit scope の count 表示 | app 側 Stimulus として維持 |
| `nav-dropdowns` | header details dropdown | native `details` の開閉に、同時 open 抑止 / outside click close / Escape close だけを lifecycle 内 listener で補う | `spec/frontend/nav_dropdowns_contract_spec.rb` で current contract を guard 済み。CSS / native details だけへの置換はここでは先取りしない |
| `document-tree-navigation` | tree link click 後の Turbo Stream refresh | document click listener、`fetch(... Accept: text/vnd.turbo-stream.html)` | Turbo Stream 補助として維持。TreeView gem API へ押し戻さない |
| `file-dropzone` | form 内 file dropzone | dragenter / dragover / drop と filename 表示 | app 側 Stimulus として維持 |
| `manual-document-upload` | preview / tree 周辺の manual upload drop | window / iframe document drag listener、hidden multipart form submit | `spec/frontend/manual_document_upload_controller_source_spec.rb` で listener lifecycle と single-file submit flow を guard 済み。複数 file や API 変更は別 issue |
| `preview-table-resizer` | Markdown preview table | iframe 内 table wrapping、localStorage、column resize、`turbo:load` / `turbo:render` refresh | current fallback path として維持。RTP 統合判断は #475 に残す |
| `preview-tools` | preview 内 search / table / code / CSV / image / PDF 補助 | `setupXxx()` library を Stimulus controller から refresh する bridge | `spec/frontend/preview_tools_source_spec.rb` で helper bridge / Turbo lifecycle / entrypoint registration を guard 済み。個別 `setupXxx()` の Stimulus 化は別 issue |
| `sidebar` | 文書ツリー sidebar width / collapsed state | localStorage、pointer / keyboard resize | app 側 Stimulus として維持 |

## 素の JavaScript / listener の棚卸し

### Entry point 直書き

`app/frontend/entrypoints/application.js` には、controller 登録以外の直接 `querySelectorAll`、直接 event listener、直接 `new TomSelect(...)` は置かれていません。新しい UI でもこの状態を維持します。

### Controller 内の document / window listener

次の listener は controller lifecycle 内に閉じているため、現時点では許容される app 側 Stimulus 初期化です。

- `document-tree-navigation`: document click を拾って tree refresh 用 Turbo Stream を取得する。
- `nav-dropdowns`: native `details` dropdown の同時 open / outside click close / Escape close を同期する。click での開閉そのものは native `details` に任せる。`spec/frontend/nav_dropdowns_contract_spec.rb` が document listener の登録 / cleanup と one-open / outside-click / Escape の代表 signal を固定している。
- `manual-document-upload`: window と iframe document の drag event を拾い、既存 upload form flow へ渡す。`spec/frontend/manual_document_upload_controller_source_spec.rb` が listener の登録 / 解除、inaccessible iframe の no-op、single file hidden multipart form submit、複数 file 未対応の境界を固定している。
- `preview-table-resizer`: iframe preview table を Turbo 再描画後にも再探索する。
- `preview-tools`: preview helper library の `setupXxx()` を Turbo 再描画後にも再実行する。`spec/frontend/preview_tools_source_spec.rb` が import する helper set、refresh 呼び出し順、Turbo listener の登録 / 解除、entrypoint に直接 DOM setup を置かない境界を固定している。
- `document-version-tabs`: hashchange に追従して tab panel を切り替える。

## Preview-tools helper bridge 分類

`preview-tools` は、preview iframe や生成済み preview DOM の補助 UI をまとめて再実行する bridge です。今回の分類は次の実装 issue を切るための棚卸しであり、helper 呼び出し順や runtime behavior は変更しません。

| helper | preview 種別 | 主な DOM / Turbo 依存 | 分割判断 | 追加 guard 候補 |
| --- | --- | --- | --- | --- |
| `setupSiteViewerIframeHeightSync` | Docusaurus / site viewer iframe | iframe load / postMessage 系の高さ同期。Turbo 再描画後に iframe を再探索する | bridge 維持。preview 種別横断の iframe 補助で、個別 preview controller へ寄せない | iframe helper が refresh 先頭で走ること |
| `setupMarkdownPreviewDocumentSearch` | Markdown preview document search | preview 内検索 UI と結果 DOM。Turbo 再描画後に再初期化する | 分割候補。検索 UI 単位の Stimulus controller に分けやすい | Markdown search helper が table / code helpers より前に走ること |
| `setupMarkdownPreviewTableTools` | Markdown preview table | preview table DOM、table 操作、既存 `preview-table-resizer` fallback path との境界 | bridge 維持。#475 / RTP 統合判断前に分割しない | Markdown table helper と codeblock helper の両方が残ること |
| `setupMarkdownPreviewCodeblockTools` | Markdown preview codeblock | preview 内 code block DOM と copy / display 補助 | 分割候補。codeblock 単位で Stimulus 化しやすい | codeblock helper が Markdown preview helper group に残ること |
| `setupDocumentFileListSearch` | document file list search | 添付・元ファイル list の query / empty state DOM | 分割候補。`document-file-browser` との責務重複を確認してから切る | file-list search helper が独立 import のまま残ること |
| `setupCsvPreviewTableTools` | CSV preview table | CSV table DOM と table 操作。Turbo 再描画後に再探索する | 分割候補。CSV preview 専用 controller として切り出しやすい | CSV helper が structured/archive/image/PDF group と混同されないこと |
| `setupStructuredPreviewTools` | structured data preview | JSON / structured preview DOM の展開や補助 | bridge 維持。preview 種別が広く、実装前に対象 DOM の棚卸しが必要 | structured helper が archive helper と別 import であること |
| `setupArchivePreviewTools` | archive preview | ZIP / archive entry list の DOM 補助 | bridge 維持。download / unsafe path 境界と近いため UI redesign と混ぜない | archive helper が unsafe-path policy を先取りしないこと |
| `setupImagePreviewTools` | image preview | image preview DOM の補助 | 分割候補。対象 DOM が比較的狭い | image helper が PDF helper と別 import であること |
| `setupPdfPreviewTools` | PDF preview | PDF preview DOM の補助 | 分割候補。PDF preview 専用 controller として切り出しやすい | PDF helper が image helper と別 import であること |

Source-level guard では、上の helper 名が docs の分類表・controller import・`refresh()` 呼び出しに揃っていることだけを固定します。分類表は candidate 判断の入口であり、個別 Stimulus controller の実装、helper 削除、Docusaurus renderer / Markdown table 方針変更は別 issue で扱います。

## Source-level guard 済みの controller

| controller | guard file | guard している境界 | guard していないこと |
| --- | --- | --- | --- |
| `preview-tools` | `spec/frontend/preview_tools_source_spec.rb` | helper bridge set、docs 上の helper 分類表、`refresh()` の呼び出し順、Turbo 再描画後の再実行、entrypoint 直書き DOM setup 回避 | helper 群の Stimulus 分割、preview UI redesign、#475 の Markdown table 方針 |
| `nav-dropdowns` | `spec/frontend/nav_dropdowns_contract_spec.rb` | controller registration、`details` markup、document listener cleanup、同時 open 抑止 / outside click / Escape close | controller 削除、navbar 情報設計、menu item / role 導線変更 |
| `manual-document-upload` | `spec/frontend/manual_document_upload_controller_source_spec.rb` | window / iframe document listener lifecycle、missing / inaccessible iframe no-op、single-file hidden form submit、複数 file 未対応 | 複数 file upload、upload API 化、manual upload review / apply contract、iframe preview redesign |

## 維持する fallback path

### Markdown preview table

`preview_table_resizer_controller.js` は、Docusaurus 生成 HTML table を Rails helper 経由で `rails_table_preferences` に接続していない current support の fallback path です。

維持する理由:

- `doc/frontend_interaction_policy.md` が app 側 preview tool として明示している。
- `spec/frontend/preview_table_resizer_source_spec.rb` が stable key と preview context marker を source-level に固定している。
- #475 は Markdown table を今後どこまで `rails_table_preferences` に寄せるかの親論点で、current support として先取りしない。

## 後続 issue に分ける候補

- `preview-tools` が呼ぶ `setupXxx()` library 群を、preview 種別ごとに Stimulus controller へ分けるか検討する。現時点では bridge helper set と docs 分類表が source-level guard 済みであり、分割を current support として書かない。
- `nav-dropdowns` は native `details` の開閉を活かしつつ、同時 open / outside click close / Escape close の current contract を app 側 controller で維持する。CSS / native details だけへ寄せる判断は、current contract を落とさない代替案が出たときに別 issue で扱う。
- `manual-document-upload` の複数 file upload、upload API 化、iframe preview UI redesign は、source guard 済みの single-file hidden form submit flow とは分けて扱う。
- Markdown preview table を `rails_table_preferences` へ寄せる判断は #475 に残し、この inventory では実装しない。
- internal UI gem pinned ref bump は #858 child issue 群に残し、この inventory では実装しない。

## この inventory の境界

- runtime behavior は変更しない。
- `application.js` の import / register は整理・削除しない。
- app 側 `new TomSelect(...)` は追加しない。
- `rails_fields_kit` / `rails_table_preferences` / `tree_view` の public API、package export、pinned ref は変更しない。
- screen-by-screen adoption や UI redesign は #607 以降の個別 issue で扱う。
