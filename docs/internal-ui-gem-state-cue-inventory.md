# internal UI gem state cue inventory

この文書は、`docs-portal` の admin UI で `tree_view` / `rails_table_preferences` / `rails_fields_kit` を並べて使うときに、状態表示 cue の意味と責務境界を読み合わせるための inventory です。

この inventory は docs-portal 側の見え方・再利用判断のための整理です。CSS custom property 名、dark mode 方針、visual diff CI、runtime CSS / JS、各 gem の public API や token 名はこの文書では決めません。API / ownership の境界は [internal UI gem責務境界matrix](./internal-ui-gem責務境界matrix.md)、screen-by-screen adoption と release train の確認順は [関連 gem 連携調査 runbook](./関連gem連携調査runbook.md) を正本にしてください。

## 読み方

- `表示目的`: admin UI 上で利用者が何を読み取れるようにする cue か。
- `代表画面 / 候補`: docs-portal 側で確認しやすい画面や候補です。実装対象の確定ではありません。
- `host app override`: docs-portal 側で文言・密度・周辺説明を調整してよい範囲です。gem-owned な class、event、helper option の新設は upstream 側の issue で扱います。
- `この issue で決めないこと`: #1470 の first slice から外す判断です。

文書ツリー refresh、preview fallback、Stimulus 化の後続候補を読むときは、current browser-side initialization の棚卸しとして [フロントエンド初期化 inventory](../doc/frontend_initialization_inventory.md) も確認します。特に `document-tree-navigation` は host app 側の Turbo Stream refresh 補助として維持し、TreeView gem の loading / error event API や retry policy をこの inventory だけで current support 化しません。

## TreeView

| state cue | 表示目的 | source gem | docs-portal の代表画面 / 候補 | host app override | 関連 docs / issue | この issue で決めないこと |
| --- | --- | --- | --- | --- | --- | --- |
| current row | いま本文側で開いている文書・行を tree 内で追跡できるようにする | `tree_view` | sidebar 文書ツリー、文書詳細 tree | current 判定は host app の route / selected document が正本。docs-portal の文書ツリーでは `current-node` 判定から link に `aria-current="page"` と `data-tree-current="true"` を付け、隣に `表示中` badge を出す。badge の文言・密度・周辺説明は host app 側の表示補助であり、gem API や token 名として扱わない。文書詳細本文側の `document-detail-state-cue` は、現在開いている版 / 本文 context を示す host app copy であり、tree の current document cue や文書一覧の filter / 表示設定とは別に読む | `docs-portal#607`, `docs-portal#858`, `docs-portal#1781`, `docs-portal#3783`, `docs-portal#4144`, `tree_view-rails#967`, `spec/frontend/document_tree_current_selection_source_spec.rb` | current 判定 API、CSS token 名、keyboard focus / selected / expanded state との統合仕様、visual diff CI |
| selected | 複数操作や一時選択がある場合に、current とは別の選択状態を示す | `tree_view` | 手動アップロード差異確認、文書ツリー操作候補 | 選択の業務意味は host app 側で説明する。gem 側 state と同じ意味に見えるかだけ確認する | `docs/手動アップロード差異確認runbook.md`, `docs-portal#607` | bulk action 導線、権限条件、selection persistence |
| collapsed / expanded | 階層を閉じているのか、子要素がないのかを誤読しない | `tree_view` | sidebar 文書ツリー、文書詳細 tree | 空 branch の説明や fallback 文言は host app 側で補える | `spec/requests/document_tree_regressions_spec.rb`, `docs/internal-ui-gem-visual-evidence-runbook.md` | 開閉状態の保存方式、localStorage / server 保存の採用判断 |
| loading | Turbo refresh や非同期更新中であることを伝える | `tree_view` / host app integration | 文書ツリー refresh 候補 | 画面側の待機文言や skeleton の有無は host app 判断。gem runtime の loading class 新設はしない | `ROADMAP.md`, `doc/frontend_initialization_inventory.md`, `docs-portal#607` | loading event API、visual regression baseline |
| error | tree 更新や読み込みに失敗した状態を通常の空状態と分ける | `tree_view` / host app integration | 文書ツリー refresh failure 候補 | 復旧案内文、再試行ボタンの有無は host app の画面 issue で扱う | `docs/internal-ui-gem-visual-evidence-runbook.md`, `doc/frontend_initialization_inventory.md`, `docs-portal#607` | retry policy、error event 名、server-side fallback |
| drop target | drag / drop 操作時に反映先を誤らないようにする | `tree_view` / host app drag surface | 手動アップロード差異確認、TreeView drop 候補 | upload / import の安全文言は host app 側。drop state の基本表現は upstream との境界を確認する | `docs/手動アップロード差異確認runbook.md`, `tree_view-rails#941` | upload contract、dry-run apply、drop event API |
| focus-visible | keyboard 操作時に現在の操作位置を明確にする | `tree_view` | sidebar 文書ツリー、文書詳細 tree | 周辺 layout の contrast と見切れ防止は host app 側で確認できる | `tree_view-rails#967`, `docs/internal-ui-gem-visual-evidence-runbook.md`, `spec/frontend/document_tree_current_selection_source_spec.rb` | focus style token、keyboard navigation spec の upstream 決定 |

## Rails Table Preferences

| state cue | 表示目的 | source gem | docs-portal の代表画面 / 候補 | host app override | 関連 docs / issue | この issue で決めないこと |
| --- | --- | --- | --- | --- | --- | --- |
| editor open | 表示設定を編集中で、通常の一覧閲覧とは状態が違うことを示す | `rails_table_preferences` | `admin/document_sets`, `admin/users`, `admin/companies` 候補 | editor 周辺の説明、閉じる導線、画面固有の補足は host app 側で調整する | `docs-portal#607`, `docs/関連gem連携調査runbook.md` | editor controller event の新設、engine route 変更 |
| active filter | 現在の一覧が絞り込み済みであることを、0 件時も読み返せるようにする | host app + `rails_table_preferences` | 文書セット、生成ファイルイベント、監査ログ | filter label / business wording は host app 正本。gem は表示設定の土台として扱う | `docs/文書セット運用runbook.md`, `docs/生成ファイル再試行と定期ジョブ管理runbook.md` | filter API、保存済み検索、検索条件の仕様変更 |
| sort | 並び順が既定ではない、または列見出しで読み取れることを示す | `rails_table_preferences` / host app table | rails_table_preferences 採用済み一覧 | sort label と default order の説明は host app 側で固定する | `docs/internal-ui-gem責務境界matrix.md`, `docs-portal#607` | DB index、server-side sort 仕様、全一覧の sort 統一 |
| preset scope | 表示設定や filter preset がどの一覧に効いているかを誤読しない | `rails_table_preferences` | `admin/document_sets` と他 admin 一覧 | table_key、preset 名、業務ラベルは host app 側で screen ごとに固定する | `docs/関連gem連携調査runbook.md`, `docs-portal#607` | mounted engine の保存契約、preset API 変更 |
| viewer table preference context | viewer 内 table がどの文書版 / site path / table key / preference context を見ているかを、後続の検証候補として読み返せるようにする | host app + `rails_table_preferences` | 版詳細 / Docusaurus・Markdown viewer の table preference 導線候補 | cue の文言、evidence comment の置き場所、runbook 補足は host app 側で決める。current renderer が出す document version / site path / table index / stable table key metadata を根拠にするが、この inventory だけで新しい runtime 表示を current support 化しない | `ROADMAP.md`, `docs-portal#4071`, `doc/frontend_initialization_inventory.md` | tree current row / ancestor expand、詳細一覧 filter / preset / column width 連携、Markdown table full RTP integration、Gemfile / pinned ref、upstream API、保存 schema、table preference persistence contract |
| fixed column | 操作列や識別列が横スクロール時も見失われないようにする | `rails_table_preferences` / host app metadata | company / user / document 系一覧候補 | どの列を固定するかは画面 issue で決める | `docs/company_master_admin会社・ユーザー管理runbook.md`, `docs-portal#607` | sticky 実装方式、全一覧への一括展開 |
| export cue | export / download に関係する操作が表示設定や filter とどう結びつくかを示す | host app + `rails_table_preferences` | 文書一覧 ZIP、AI context export、一覧 export 候補 | export の対象件数・権限・注意文言は host app 側で決める | `docs/文書一覧の検索・実用フィルタ・ZIP出力runbook.md`, `docs/AI向けコンテキストexport運用runbook.md` | export contract、非同期ジョブ、CSV / ZIP 仕様 |
| validation / empty state | 保存失敗や 0 件時を、通常の table と誤読しない | `rails_table_preferences` / host app view | 初回登録系 index、0 件の管理一覧 | empty copy、次の操作、colspan は host app 側で screen ごとに固定する | `docs-portal#607`, `docs/関連gem連携調査runbook.md` | validation policy、all screens の empty state redesign |

## Rails Fields Kit

| state cue | 表示目的 | source gem | docs-portal の代表画面 / 候補 | host app override | 関連 docs / issue | この issue で決めないこと |
| --- | --- | --- | --- | --- | --- | --- |
| selected item | 選択済みの値が validation rerender や preload 後も読み取れる | `rails_fields_kit` | `admin/document_sets` form、`admin/documents` project selector、`admin/document_permissions` canary | field label / collection / required 説明は host app 正本 | `docs-portal#607`, `docs-portal#737`, `docs/関連gem連携調査runbook.md` | 保存 params、業務 validation、collection query |
| loading | remote search や selected preload 中に未確定状態を示す | `rails_fields_kit` | remote search を持つ form 候補 | loading 中の補足文言や surrounding helper text は host app 側で扱う | `rails_fields_kit#662`, `docs-portal#737` | remote endpoint、debounce、loading event API |
| remote error | 検索候補取得失敗を validation error や未選択と分ける | `rails_fields_kit` + host app opt-in | `admin/document_permissions` の canary 候補 | field 近傍の復旧文言は host app 側。`error_surface` の contract は upstream 側を参照する | `docs-portal#737`, `rails_fields_kit#136` | retry policy、message semantics の全面見直し |
| selected preload error | 既存値の読み込み失敗を、保存値がない状態と誤読しない | `rails_fields_kit` + host app opt-in | `admin/document_permissions` の canary 候補 | stale state の消し方と案内は canary issue で最小固定する | `docs-portal#737`, `rails_fields_kit#136` | 全 form 横展開、upstream helper option 変更 |
| validation error | Rails validation の失敗を field 近傍で見せ、remote failure と分ける | host app + `rails_fields_kit` helper | `admin/document_sets` form、文書マスタ系 form | 業務 validation 文言は host app 正本。gem は表示 hook と再描画保持を担う | `docs/文書マスタ運用runbook.md`, `docs-portal#607` | model validation、controller state、schema |
| disabled | 権限や状態により編集できない理由を、単なる loading と分ける | host app + `rails_fields_kit` | 管理 form、company_master_admin scope 候補 | disabled の理由・権限説明は host app の画面 issue で扱う | `docs/company_master_admin会社・ユーザー管理runbook.md`, `docs-portal#607` | authorization、role policy、field availability contract |
| focus | keyboard / screen reader 操作時に field の操作位置を明確にする | `rails_fields_kit` / Tom Select integration | RFK 採用済み form | surrounding layout の見切れや label 関係は host app 側で確認する | `docs/internal-ui-gem-visual-evidence-runbook.md`, `docs-portal#607` | Tom Select core behavior、focus token、visual baseline |

## 横断で揃える判断メモ

| 観点 | docs-portal 側で揃えること | upstream / 別 issue に残すこと |
| --- | --- | --- |
| 同じ意味の cue | `current`, `selected`, `active filter`, `selected item` のように、似た語でも対象が違うものは画面文脈で読み分ける。文書詳細では、本文側の `表示中` は現在開いている版 / 本文 context、左ペイン文書ツリーの `表示中` badge は現在文書、文書一覧の検索・表示設定は一覧画面側の条件として分けて読む | gem 共通 vocabulary の public API 化 |
| 周辺文言 | admin UI の業務ラベル、復旧案内、0 件時の次アクションは host app で書く | gem 側の default message や helper option 変更 |
| 見た目の密度 | 同じ admin 画面に置いたときに過度に目立つ / 埋もれる cue を screen issue で調整する | global token、dark mode、全 gem 共通 CSS |
| 証跡 | static artifact を触ったら visual evidence runbook、runtime screen adoption は関連 request / helper spec と PR 本文へ残す | visual diff CI や screenshot baseline の導入 |
| release train | pinned ref 更新では representative smoke と rollback target を記録し、この inventory は state cue の読み合わせに使う | Gemfile pin 更新、upstream PR の merge 判断 |

## 後続 issue からの使い方

- `docs-portal#607`: screen-by-screen adoption で、画面ごとにどの state cue を確認すべきかを選ぶ入口にする。
- `docs-portal#737`: RFK error surface canary で、remote error / selected preload error / validation error の境界を読み分ける。
- `docs-portal#858` child issue: release train の representative smoke を選ぶときに、どの cue が host app で重要かを確認する。
- `docs-portal#4071`: `ResourceTableRenderState` の文書閲覧 UX 反映候補を、viewer 内 table preference context cue の proposal / evidence boundary として読む。
- `tree_view-rails#941` / `tree_view-rails#967`: TreeView の token や focus / current-row cue は upstream 側で決め、この inventory では docs-portal 側の見え方要件として参照する。
