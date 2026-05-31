# internal UI gem visual evidence gallery

この文書は、`docs-portal` の代表画面から `rails_fields_kit` / `rails_table_preferences` / `tree_view-rails` の visual evidence を辿るための index です。

採用順、依存、target SHA、rollback note は [internal UI gem責務境界matrix](./internal-ui-gem責務境界matrix.md) と [関連 gem 連携調査 runbook](./関連gem連携調査runbook.md) を正本にします。この gallery は design reviewer が「先に見る upstream evidence」と「docs-portal 側で追加確認する downstream evidence」を画面別に見分ける入口だけを扱います。

## 使い方

1. 変更対象の代表画面をこの gallery で探す。
2. `先に見る upstream evidence` で、gem 側の visual reference / mockup / sample app evidence を確認する。
3. `docs-portal 側で残す evidence` で、PR comment や child issue に残す host app 側の確認範囲を決める。
4. `境界` に書いた内容を越える場合は、screen adoption / pinned ref update / upstream gem issue に分ける。

`built-in UI` は gem が提供する general surface、`host-app-owned UI` は docs-portal の画面固有の field、column、route、permission、業務 label です。host-app-owned UI の意味を upstream gem の責務として書き換えないでください。

## 代表画面別 index

| docs-portal 代表画面 | 関係する gem surface | 先に見る upstream evidence | docs-portal 側で残す evidence | 境界 |
| --- | --- | --- | --- | --- |
| `admin/document_sets` form | `rails_fields_kit` の `form.rfk_select`、Tom Select controller、selected value / validation rerender | `rails_fields_kit` の `doc/visual_references.md`、`doc/visual_reference_index.html`、`doc/final_release_checklist.md` | initial load、selected value、placeholder、invalid rerender、request spec のどこを確認したか | collection、field 名、保存 params、validation は docs-portal 側の正本。remote search endpoint や helper option 設計は別 issue |
| `admin/documents` form | `rails_fields_kit` の `project_id` canary | `rails_fields_kit` の visual reference family と public setup docs | `project_id` だけが RFK 対象であること、他 field を置き換え済み扱いしないこと、invalid rerender の確認範囲 | `category` / `document_kind` / `visibility_policy` の置き換え、remote search、他 form 横展開はこの gallery で決めない |
| `admin/document_sets` list | `rails_table_preferences` の table editor、stable column key、filter / preset、mounted engine save | `rails_table_preferences` の `docs/index.md`、README、package verification / manual QA 系 docs | editor / table / filter / preset / mounted engine save、empty state、rollback target | document set 固有の列名、固定版 / 最新版の業務意味、公開範囲 label は docs-portal 側の正本 |
| `admin/documents`, `admin/projects`, `admin/users`, `admin/external_folder_sync_sources` lists | `rails_table_preferences` の column metadata、display preference、filter state | `rails_table_preferences` の docs index と table preference guide family | stable column key、filter / preset、0 件 state、保存済み設定の代表 smoke | 新しい一覧への一括展開や Markdown preview table 採用可否は別 issue。current main に未着地の table 対応を実装済みとして書かない |
| viewer sidebar tree / document detail tree | `tree_view-rails` の render helper、row state、selection、persisted state mockup | `tree_view-rails` の `docs/mockups/review-gallery.html`、`docs/mockups/README.md`、default tree / row status / lazy-loading 系 mockup | sidebar tree、detail tree、persisted state、window offset の代表 smoke と rollback note | query、権限、route、icon、業務 label、current node 判定は docs-portal 側の正本。package-root JS adoption は current code と分ける |
| generated file operations (`admin/generated_file_*`) | 運用 table / action density。`rails_table_preferences` は実装済み画面だけ対象 | `rails_table_preferences` の visual / manual QA docs。ただし対象画面が current main で table preference 化済みか先に確認する | notice、status badge、action button、table density、最新件数や関連 run の読み方 | open PR や未merge issue の UI を current support として先取りしない。retry policy、dispatch logic、生成 job contract は別 docs / issue |
| external sync / import review screens | `tree_view-rails` の tree state、`rails_table_preferences` の table state、host app の dry-run review UI | tree mockup gallery、RTP table docs、既存 import / sync runbook | dry-run preview、差分 table、tree preview、apply / rollback note のどこを見たか | provider ごとの同期本体、Graph subscription、preview iframe fallback の仕様判断はこの gallery で決めない |

## downstream evidence の置き場所

- screen adoption の child issue / PR には、代表画面、参照した upstream artifact path、host smoke の範囲、未取得の visual evidence を 1 セットで残す。
- pinned ref update train では、gem / from / to / representative smoke / result / rollback target を [関連 gem 連携調査 runbook](./関連gem連携調査runbook.md) の update log template に合わせる。
- static artifact を直接変えた PR では、[internal UI gem visual evidence runbook](./internal-ui-gem-visual-evidence-runbook.md) の `visual evidence` template を使う。
- screenshot が取れない場合は、source inspection、request smoke、CSS arithmetic、manual spot check のどれで代替したかを明記する。

## Planner / Fixer への渡し方

- `#1407` は採用順、依存、検証証跡 matrix の正本として扱う。
- この gallery は、代表画面別に visual evidence を探す入口として使う。
- upstream gem の public API、helper option、controller identifier、event name、package-root export の正誤判断は upstream issue / PR に戻す。
- current code、Issue、既存 docs から判断できない visual behavior は `needs-human` として扱い、docs-portal 側で仕様を作らない。

## 非目標

- production UI / CSS / JavaScript の変更
- screenshot automation や visual regression CI の追加
- upstream gem の mockup / visual reference の修正
- docs-portal の全画面棚卸し
- target SHA や known-good revision の人間判断の代替
