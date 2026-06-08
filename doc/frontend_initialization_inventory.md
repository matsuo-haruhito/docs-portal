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
| `nav-dropdowns` | header details dropdown | native `details` の開閉に、同時 open 抑止 / outside click close / Escape close だけを lifecycle 内 listener で補う | CSS / native details だけでは current contract を満たせないため、小さな app 側 controller として維持 |
| `document-tree-navigation` | tree link click 後の Turbo Stream refresh | document click listener、`fetch(... Accept: text/vnd.turbo-stream.html)` | Turbo Stream 補助として維持。TreeView gem API へ押し戻さない |
| `file-dropzone` | form 内 file dropzone | dragenter / dragover / drop と filename 表示 | app 側 Stimulus として維持 |
| `manual-document-upload` | preview / tree 周辺の manual upload drop | window / iframe document drag listener、hidden form submit | app 固有 upload flow として維持。複数 file や API 変更は別 issue |
| `preview-table-resizer` | Markdown preview table | iframe 内 table wrapping、localStorage、column resize、`turbo:load` / `turbo:render` refresh | current fallback path として維持。RTP 統合判断は #475 に残す |
| `preview-tools` | preview 内 search / table / code / CSV / image / PDF 補助 | `setupXxx()` library を Stimulus controller から refresh する bridge | 維持する bridge。個別 `setupXxx()` の Stimulus 化は別 issue |
| `sidebar` | 文書ツリー sidebar width / collapsed state | localStorage、pointer / keyboard resize | app 側 Stimulus として維持 |

## 素の JavaScript / listener の棚卸し

### Entry point 直書き

`app/frontend/entrypoints/application.js` には、controller 登録以外の直接 `querySelectorAll`、直接 event listener、直接 `new TomSelect(...)` は置かれていません。新しい UI でもこの状態を維持します。

### Controller 内の document / window listener

次の listener は controller lifecycle 内に閉じているため、現時点では許容される app 側 Stimulus 初期化です。

- `document-tree-navigation`: document click を拾って tree refresh 用 Turbo Stream を取得する。
- `nav-dropdowns`: native `details` dropdown の同時 open / outside click close / Escape close を同期する。click での開閉そのものは native `details` に任せる。
- `manual-document-upload`: window と iframe document の drag event を拾い、既存 upload form flow へ渡す。
- `preview-table-resizer`: iframe preview table を Turbo 再描画後にも再探索する。
- `preview-tools`: preview helper library の `setupXxx()` を Turbo 再描画後にも再実行する。
- `document-version-tabs`: hashchange に追従して tab panel を切り替える。

## 維持する fallback path

### Markdown preview table

`preview_table_resizer_controller.js` は、Docusaurus 生成 HTML table を Rails helper 経由で `rails_table_preferences` に接続していない current support の fallback path です。

維持する理由:

- `doc/frontend_interaction_policy.md` が app 側 preview tool として明示している。
- `spec/frontend/preview_table_resizer_source_spec.rb` が stable key と preview context marker を source-level に固定している。
- #475 は Markdown table を今後どこまで `rails_table_preferences` に寄せるかの親論点で、current support として先取りしない。

## 後続 issue に分ける候補

- `preview-tools` が呼ぶ `setupXxx()` library 群を、preview 種別ごとに Stimulus controller へ分けるか検討する。
- `nav-dropdowns` は native `details` の開閉を活かしつつ、同時 open / outside click close / Escape close の current contract を app 側 controller で維持する。
- `manual-document-upload` の iframe drag listener と upload submit flow を、behavior を変えずに source-level guard で固定する。
- Markdown preview table を `rails_table_preferences` へ寄せる判断は #475 に残し、この inventory では実装しない。
- internal UI gem pinned ref bump は #858 child issue 群に残し、この inventory では実装しない。

## この inventory の境界

- runtime behavior は変更しない。
- `application.js` の import / register は整理・削除しない。
- app 側 `new TomSelect(...)` は追加しない。
- `rails_fields_kit` / `rails_table_preferences` / `tree_view` の public API、package export、pinned ref は変更しない。
- screen-by-screen adoption や UI redesign は #607 以降の個別 issue で扱う。
