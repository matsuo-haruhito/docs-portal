# internal UI gem table contract first slice

このメモは `docs-portal#4271` の first slice として、RFK / RTP / TreeView の table integration contract を docs-portal の採用順へ戻すための短い整理です。

ここでは runtime code、Gemfile / Gemfile.lock、pinned ref、upstream API、visual evidence batch は変更しません。`ROADMAP.md`、[internal UI gem state cue inventory](./internal-ui-gem-state-cue-inventory.md)、[internal UI gem責務境界matrix](./internal-ui-gem責務境界matrix.md)、[internal UI gem adoption evidence map](./internal-ui-gem-adoption-evidence-map.md) を読むときの #4271 用の補助メモとして扱います。

## representative screen

first representative screen は `案件詳細の文書ツリー + 文書一覧` に絞ります。

理由:

- TreeView の hierarchy / expansion / current cue が文書ツリー側に現れる。
- RTP の visible columns / table state / preference UI / filter or preset cue が文書一覧側に現れる。
- RFK の filter / form helper / selected state は、文書一覧や関連する絞り込み導線の責務として読み合わせられる。
- docs-portal の query execution、authorization、route / params、business copy が同じ画面文脈で必要になる。
- `docs-portal#3741` の feature proposal と重ねて読めるが、このメモでは #3741 の runtime 実装へ進まない。

## responsibility map

| layer | #4271 で読む責務 | docs-portal 側の代表確認 | この first slice でしないこと |
| --- | --- | --- | --- |
| RFK / `rails_fields_kit` | field rendering、rendered metadata、helper-side selected state、RFK helper を使う入力補助の境界 | 絞り込みや関連選択の selected value / invalid rerender / helper wiring を host app の文脈で読む | upstream helper option、endpoint policy、Tom Select core behavior、RFK release train を変更しない |
| RTP / `rails_table_preferences` | column inference、visible columns、table state、preference UI、renderer registry guard | 文書一覧や代表一覧の stable column key、filter / preset、table key、mounted engine save evidence を host app evidence として読む | Gemfile bump、known-good SHA 決定、Markdown table full RTP integration、host app 固有 label を upstream contract として固定しない |
| TreeView / `tree_view-rails` | hierarchy row rendering、visible row order、expansion state、current cue、table_state fallback guard | 文書ツリーの current document cue、ancestor expansion、detail tree smoke、TreeView state と一覧 state の読み分けを確認する | package-root JS adoption、visual evidence batch、focus token / event API、TreeView public API 変更をしない |
| docs-portal host app | query execution、authorization、business copy、screen composition、route / params、state cue の読み分け | 案件詳細の文書ツリー + 文書一覧で、文書閲覧権限、route context、filter copy、table / tree の状態説明を host app 正本として扱う | 権限モデル、DB schema、table preference persistence contract、全 screen 横展開を変更しない |

## upstream issue adoption order

| upstream / related issue | #4271 での扱い | 理由 |
| --- | --- | --- |
| `rails_table_preferences#1026` | Fixer-ready な upstream guard として参照する。docs-portal 側で再 planning しない | renderer registry docs / package surface drift guard は RTP 側の責務で、docs-portal の representative screen 整理とは分ける |
| `tree_view-rails#946` | Fixer-ready な upstream guard として参照する。docs-portal 側で再 planning しない | `ResourceTableRenderState` の table_state / visible_columns fallback guard は TreeView 側で守る |
| `rails_fields_kit#2464` | Planner 行き候補として参照する | table native metadata focused docs の inventory guard 候補だが、まだ `agent:planned` ではない |
| `rails_fields_kit#2443` / `#2446` | merged / prior evidence としてだけ読む | custom renderer registry guard は downstream table contract の背景になるが、#4271 の blocker として固定しない |
| `docs-portal#3741` | representative screen の proposal 受け皿として参照する | この Issue では runtime 実装、route / controller、table preference persistence 変更へ進まない |

## related docs-portal lanes

| issue | #4271 との役割差 |
| --- | --- |
| `docs-portal#607` | screen-by-screen adoption の大きな共通パターン。#4271 は代表画面 1 つと table contract map に絞る |
| `docs-portal#858` | pinned ref / smoke / rollback note の release train。#4271 では target SHA や Gemfile 更新を決めない |
| `docs-portal#3817` | release train sequencing hub。#4271 は release baseline の代替ではなく、downstream smoke 前提の責務整理だけを扱う |
| `docs-portal#4155` | static visual PR evidence batch。#4271 では browser evidence や screenshot approval CI を扱わない |

## acceptance checklist

- [x] representative screen を `案件詳細の文書ツリー + 文書一覧` に絞った。
- [x] RFK / RTP / TreeView / docs-portal の responsibility boundary を 1 枚の表で読めるようにした。
- [x] upstream 既存 Issue のうち、Fixer-ready / Planner 行き / evidence-only を分けた。
- [x] Gemfile bump、upstream API redesign、visual evidence batch、full table preference integration を混ぜない境界を明記した。
- [x] `docs-portal#607` / `#858` / `#3817` / `#4155` との役割差を分けた。
