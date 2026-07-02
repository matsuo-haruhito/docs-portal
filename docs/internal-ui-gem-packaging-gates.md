# internal UI gem packaging gate runbook

この文書は、`docs-portal` の internal UI gem release train (`#858`) で、上流 3 gem の packaging gate 完了状況を確認するときの補助 runbook です。`docs/関連gem連携調査runbook.md` の release train matrix と併用し、actual pinned ref bump や smoke 実行は各 child issue / PR に残します。

## 使うタイミング

- `#991` / `#903` / `#904` のような pinned ref 更新 slice に入る前
- `Gemfile.lock` の from / to revision を決める前に、上流 gem 側で package contents check がどこまで整っているか確認したいとき
- downstream smoke が落ちたときに、packaging drift か `docs-portal` 側の helper / partial / spec drift かを切り分けたいとき

この文書は gate 完了状況の索引です。target SHA の最終判断、Gemfile / lockfile 更新、代表 smoke の実行結果、rollback target は各 child issue / PR の update log に残します。

## 上流 packaging gate 完了状況

| upstream | 完了した gate | downstream で信頼してよいこと | docs-portal 側でまだ確認すること |
| --- | --- | --- | --- |
| [`rails_fields_kit#500`](https://github.com/matsuo-haruhito/rails_fields_kit/pull/500) | built `.gem` artifact から packaged `package.json` と `exports["."]` / `exports["./tom_select_controller"]` の target files を確認する CI gate | package-root import と direct Tom Select controller entrypoint が packaged artifact に入ること | `admin/document_sets` form の selected value / placeholder / validation rerender、`application.js` / `vite.config.ts` / initializer の wiring |
| [`tree_view-rails#825`](https://github.com/matsuo-haruhito/tree_view-rails/issues/825) | built gem に JavaScript / CSS / importmap entrypoint が入ることを確認する release safety lane | host app が必要とする tree_view JavaScript / asset / importmap entrypoint が packaging 対象から落ちにくいこと | sidebar tree、detail tree、persisted state、route context、`documents_helper` / `projects_helper` の app-side row 文脈 |
| [`rails_table_preferences#428`](https://github.com/matsuo-haruhito/rails_table_preferences/issues/428) | built gem から `package.json` exports と package-root / direct controller JavaScript entrypoints を確認する quality gate。`rails_table_preferences#798` の planned 方針では `README.md`、`docs/index.md` family、`docs/javascript_entrypoints.md`、release checklist、package verifier を source-of-truth family として読む | `rails_table_preferences` package root と `rails_table_preferences/controller` の packaged entrypoint が残ること。package-root named export、direct controller import、packaged copied/package controller files の確認先を upstream docs / verifier で分けて読めること | `admin/document_sets` の editor / filter / preset / mounted engine save、Markdown preview table fallback と混ぜていないこと。table key、stable column key、filter / sort mapping、preset behavior、rollback target は docs-portal 側の representative smoke として別に残すこと |

## docs-portal release train での読み方

1. `docs/関連gem連携調査runbook.md` の current resolved revision matrix で、対象 gem の current SHA と child lane を確認する
2. この文書の表で、上流 packaging gate がどの artifact / entrypoint を守っているか確認する
3. child issue (`#991` / `#903` / `#904`) で target SHA を決め、`Gemfile.lock` の from / to revision を update log に残す
4. representative smoke は `docs-portal` 側で必ず実施し、上流 gate の成功だけで host app integration 成功とは扱わない
5. packaging gate で守られていない画面固有の DOM、route、permission、table key、selected value は `docs-portal` 側の evidence として分けて記録する

## cross-repo handoff checklist

`#4359` 型の横断整理では、3 gem を同じ gate に押し込まず、次の順で確認してから downstream smoke issue へ渡します。

1. package root / entrypoint が artifact に含まれるかを見る。RTP は package verifier と `docs/javascript_entrypoints.md`、TreeView は public API manifest と package-root registration docs、RFK は package contents / public API docs を主 evidence にする。
2. TypeScript declaration、public manifest、direct helper subpath は gem ごとに扱いが違うため、別 gem の guard 名をそのまま required gate として移植しない。
3. CI success は package / source guard の成功として記録し、browser visual approval や docs-portal host app smoke の代替にしない。
4. downstream issue / PR には `from SHA`、`to SHA`、参照した upstream PR / workflow run、未取得の visual evidence gate、rollback target を分けて残す。

この checklist は review / handoff の見落としを減らすためのものです。upstream PR の review、Gemfile bump、3 gem 一括更新、browser screenshot 取得はそれぞれの担当 issue / PR へ戻します。

## current pinned refs

current `main` の `Gemfile.lock` では、次の revision が解決されています。

| gem | current resolved revision | release train の読み方 |
| --- | --- | --- |
| `rails_fields_kit` | `0c29bb935a1df3e61add860a966a2fc7ea586b1a` | baseline child `#783` 後の前提 revision。次の target SHA は child issue 側で決める |
| `tree_view` | `9c538f9ee7946fa5af24f15c99402a0431677303` | `#903` の update log で target SHA、sidebar / detail tree smoke、rollback target を残す |
| `rails_table_preferences` | `b3f1a9d6eb46aefe568c637396fab63151aef322` | `#904` の update log で target SHA と admin/document_sets smoke を残す。known-good 判断は `#789` と分け、upstream evidence family と downstream smoke を別項目で記録する |

## 非目標

- Gemfile / Gemfile.lock の更新
- upstream gem の package verification script 再設計
- docs-portal の代表 smoke 実行や spec 追加
- host-app 採用パターン `#607` の全面整理
- Markdown preview table へ `rails_table_preferences` を導入するかどうかの仕様判断

## update log に残す最小情報

```text
- gem: <rails_fields_kit | tree_view | rails_table_preferences>
- upstream packaging gate checked:
  - <rails_fields_kit#500 | tree_view-rails#825 | rails_table_preferences#428>
- from: <Gemfile.lock current SHA>
- to: <target SHA or tag>
- representative smoke:
  - <docs-portal の画面 / request spec / system spec>
- result:
  - <通ったこと、落ちたこと、追加 follow-up>
- rollback target:
  - <戻す SHA or tag>
```

上流 packaging gate は「artifact に必要 entrypoint が入っている」ことの確認です。`docs-portal` 側の route、helper、partial、CSS、Stimulus wiring、権限制御、代表 smoke まで代替するものではありません。
