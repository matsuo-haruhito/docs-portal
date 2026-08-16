# Internal UI Gem 責務境界

inclusion: manual

---

## 統合元ファイル一覧

| ファイル | 最終 commit |
|---------|-------------|
| docs/internal-ui-gem責務境界matrix.md | 17ed84751f4860d27a90e8693877e5e9a7cd2619 |
| docs/internal-ui-gem-packaging-gates.md | d39e603be830e94bd5802225d1ff9bcc82c86576 |
| docs/internal-ui-gem-js-resolver-matrix.md | d39e603be830e94bd5802225d1ff9bcc82c86576 |
| docs/internal-ui-gem-public-surface-package-verification-matrix.md | a8e9a4c6538c23eecb4cd445cb3d629023e78446 |

---

host app（docs-portal）と upstream gem 側の API / ownership / representative smoke の境界。

## 責務境界 Matrix

| gem | host app 側（docs-portal が担当） | gem 側（upstream が担当） |
|-----|----------------------------------|--------------------------|
| `tree_view` | 文書ツリー / 詳細ツリーの render state・行描画・開閉・persisted state の組み込み確認。`documents_helper`・`projects_helper`・`_tree.html.slim`・`_document_detail_tree.html.slim`・`tree_view_state_owner` concern が正本 | 文書 query、権限制御、route、icon、業務ラベル、current node 判定を gem 側責務にしない。render helper / toolbar / event 名 / controller identifier の設計変更は upstream issue で扱う |
| `rails_table_preferences` | 一覧の column metadata、表示設定 editor、stable column key、filter / preset、mounted engine 保存、未ログイン redirect、owner-scoped preference isolation の host 側組み込み確認。`admin/document_sets` が代表画面 | 案件・文書固有の pinned 判断、filter label、業務列の意味、認可境界を gem 側へ押し戻さない。engine contract / helper option の設計変更は upstream で扱う |
| `rails_fields_kit` | form helper、Tom Select wiring、selected value、preload / remote search、validation rerender 後の再表示確認。`admin/document_sets` form・`admin/documents` の `project_id` canary が代表 | field 名、collection、業務 validation、保存時の params contract を gem 側で定義しない。helper export / rendered-field contract の設計変更は upstream で扱う |

### Representative Smoke

| gem | 代表画面 | 確認するもの |
|-----|---------|-------------|
| `tree_view` | sidebar tree、detail tree | persisted state、window offset、route context |
| `rails_table_preferences` | `admin/document_sets` | editor / table / filter / preset / mounted engine save / login redirect / owner-scope isolation |
| `rails_fields_kit` | `admin/document_sets` form | initial load / selected value 保持 / placeholder / invalid rerender |

## Packaging Gates

release train で upstream packaging gate と downstream smoke の境界。

| Gate | 確認内容 | 通過条件 |
|------|---------|---------|
| `rails_fields_kit#500` | built `.gem` から `package.json` の `exports["."]` / `exports["./tom_select_controller"]` の target files を確認する CI gate | package-root import と direct Tom Select controller entrypoint が packaged artifact に入ること |
| `tree_view-rails#825` | built gem に JavaScript / CSS / importmap entrypoint が入ることを確認する release safety lane | host app が必要とする tree_view JavaScript / asset / importmap entrypoint が packaging 対象から落ちにくいこと |
| `rails_table_preferences#428` | built gem から `package.json` exports と package-root / direct controller JavaScript entrypoints を確認する quality gate | `rails_table_preferences` package root と `/controller` の packaged entrypoint が残ること |

### Gate の読み方

1. 上流 packaging gate は「artifact に必要 entrypoint が入っている」ことの確認
2. docs-portal 側の route、helper、partial、CSS、Stimulus wiring、権限制御、代表 smoke まで代替しない
3. CI success は package / source guard の成功として記録し、browser visual approval や host app smoke の代替にしない
4. downstream issue / PR には `from SHA`、`to SHA`、参照した upstream PR / workflow run、未取得の visual evidence gate、rollback target を分けて残す

## JS Resolver 境界

package-root import、documented direct entrypoint、Vite resolver の downstream 境界。

| gem | docs-portal current import | Vite resolver | upstream package-root public surface | documented direct entrypoint | 境界 |
|-----|---------------------------|---------------|-------------------------------------|-----------------------------|----- |
| `tree_view` | `import { registerTreeViewControllers } from "tree_view"` → application.ts で `registerTreeViewControllers(application)` として呼び出し | `tree_view` alias あり（`vite.config.ts`） | `config/public_api_manifest.yml` の `javascript_package_root.named_exports`（`registerTreeViewControllers` 等） | package-root を入口に扱う。gem 内部 path は durable import にしない | package-root import を採用済み。raw event 名 / controller identifier の写経を避ける |
| `rails_table_preferences` | `import { RailsTablePreferencesController } from "rails_table_preferences"` → `rails-table-preferences` として register | `rails_table_preferences` と `rails_table_preferences/controller` の alias あり | `docs/javascript_entrypoints.md` が package root named export を案内 | `rails_table_preferences/controller` は documented fallback / migration lane | screen issue では package-root import を基準にする。direct path は fallback に閉じる |
| `rails_fields_kit` | `import { TomSelectController as RailsFieldsKitTomSelectController } from "rails_fields_kit"` → ExtendedRfkTomSelectController として拡張・register | `rails_fields_kit` と `rails_fields_kit/tom_select_controller` の alias あり | `doc/public_api.md` が package root named export `TomSelectController` を案内 | `rails_fields_kit/tom_select_controller` は documented | new helper を downstream docs に書く前に upstream public export か確認する。未着地 upstream PR の export 名を durable contract にしない |

### Import 方式の判断基準

- package-root import を採用する場合: current `application.ts` と upstream public API docs が根拠
- documented direct entrypoint を fallback として参照する場合: upstream Vite / app/frontend docs と migration lane が根拠
- Issue / PR には選んだ方式を 1 行で残す

## Public Surface / Package Verification

public export、TypeScript declaration、manifest、verification signal の責務分担。

| gem | package-root public export | TypeScript declaration | public API manifest | package verification boundary | docs-portal durable contract |
|-----|---------------------------|----------------------|--------------------|-----------------------------|------------------------------|
| `tree_view` | `config/public_api_manifest.yml` の named_exports が管理 | current downstream では adoption gate にしない。型定義追加は smoke / rollback note とは別扱い | adopter-visible contract 候補。配布境界は upstream `tree_view-rails#981` の判断に従う | package-root export と manifest / docs の drift を upstream guard で見る。docs-portal 側で verifier policy を再定義しない | sidebar tree、detail tree、persisted state、route context の代表 smoke。JS public hook 採用は先取りしない |
| `rails_table_preferences` | `docs/javascript_entrypoints.md` が package root named export を案内。docs-portal current import も package root | package entrypoint の `.d.ts` 同梱は upstream signal。merge されるまで required contract にしない | current adoption では manifest を正本にしない。documented entrypoint docs と package verification signal を優先 | gemspec / package contents / entrypoint docs / type declaration の drift を upstream で確認。CI 判定へ package policy を持ち込まない | `admin/document_sets` の editor、stable column key、mounted engine save、filter / preset smoke |
| `rails_fields_kit` | `doc/public_api.md` が `TomSelectController` と rendered-field contract helpers を案内 | 型定義は upstream package-root / setup-note follow-up の結果に従う。未着地の declaration 名を durable contract にしない | current adoption では manifest を正本にしない。public API docs と generated setup note / package contents guard を確認 | package-root export、generated setup note、package contents guard の drift を upstream で確認。field helper の request spec と representative smoke に閉じる | `admin/document_sets` form の selected value 保持、placeholder、invalid rerender、Tom Select wiring smoke |

### 責務判断ルール

| 判断対象 | docs-portal で参照してよいもの | docs-portal で決めないもの |
|---------|------------------------------|--------------------------|
| package-root import 採用 | current `application.ts`、`vite.config.ts`、upstream README / public API docs | upstream package-root export の命名変更や互換 policy |
| direct entrypoint 文書化 | upstream が documented fallback として案内している path | gem 内部 path を durable public path として勝手に昇格すること |
| TypeScript declaration gate | merge 済み upstream docs / package contents / CI result | 未 merge の declaration PR を必須条件にすること |
| manifest 採用判断 | upstream が adopter-visible artifact として扱うと決めた manifest | manifest schema や配布境界の再設計 |
| package verification の読み方 | upstream package contents / gemspec / CI 判定の結果 | upstream verifier の責務を肩代わりすること |

## Pinned Ref 更新ルール

`#858` family の bump では `1 gem = 1 branch = 1 PR` を基本とし、以下を issue / PR に残す:

```text
- gem: <rails_fields_kit | tree_view | rails_table_preferences>
- from: <current SHA>
- to: <target SHA or tag>
- representative smoke: <docs-portal の画面 / spec>
- result: <通った / 落ちた / follow-up>
- rollback target: <戻す SHA or tag>
```

3 gem を同じ branch に混ぜない。upstream CI / packaging gate の成功だけで host app integration 成功とは扱わない。


## 削除済み historical evidence

以下のファイルは historical evidence のみで構成されていたため削除済み。内容は git 履歴で参照可能。

| ファイル | 最終 commit |
|---------|-------------|
| docs/internal-ui-gem-release-evidence-matrix.md | 8f8ab6d3a83cba2d7e18573b24619d77f1f7d69d |
| docs/internal-ui-gem-release-train-snapshot-2026-06-05.md | cccd6d61e7aec2988c5a6f134ae428e597a72a90 |
| docs/internal-ui-gem-release-train-current-wave-2026-06-12.md | 31e45414d4d72c257537b315db1e68262a5378e4 |
| docs/internal-ui-gem-release-train-adoption-gates.md | e7ff5481f52675d8c0f7e4d47fffb845772004af |
| docs/internal-ui-gem-upstream-readiness-snapshot.md | f1b69319a00b8cccfbf46c5320ac57b4fcbeba01 |
| docs/internal-ui-gem-cross-repo-queue-order.md | 3ae6c7081a3be3f371444e544b60f9c494666542 |
| docs/internal-ui-gem-table-contract-first-slice.md | aa6b3a863e149c0fc0676fc0144483273edde21d |
| docs/internal-ui-gem-treeview-rtp-bridge-decision.md | d1e2a54229ad24c6d0ea3c5d92e08b8b2b47192e |
| docs/internal-ui-gem-rtp-rfk-document-sets-canary.md | 012edbaad8e1b4775d1cc821b08d02a9e1bd931a |
| docs/internal-ui-gem-state-cue-inventory.md | d37de69c110861535f0e98cecf15a87148c346a3 |
| docs/internal-ui-gem-visual-evidence-gallery.md | 53b2cfa4235a8a9b5f106857f68e8ef803ea5bf3 |
| docs/bootstrap-internal-ui-gem-smoke.md | 212104dffc6c2bf82ffd4a8457ed0d0d2bb8079d |
| docs/internal-gem-release-train-smoke.md | be861ce06e2b4a3064e10aa3cd08186884e61954 |
| docs/internal-ui-gem-release-train-readiness-matrix.md | c68b817b520357a655801b3759c1e4d3d7bafd96 |
