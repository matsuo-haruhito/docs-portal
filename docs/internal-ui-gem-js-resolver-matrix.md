# internal UI gem JS resolver matrix

この文書は、`docs/関連gem連携調査runbook.md` の `package-root import / direct entrypoint の使い分け` を、3 gem 横断で同じ粒度にそろえて確認するための早見表です。

`docs-portal` が current main で実際に import / register しているものと、upstream gem が公開している package-root export / direct entrypoint を混同しないことを目的にします。ここでは runtime code、`Gemfile`、`Gemfile.lock`、`vite.config.ts` は変更しません。

package verification、TypeScript declaration、public API manifest、CI package-sensitive 判定の責務分担は、隣接する `docs/internal-ui-gem-public-surface-package-verification-matrix.md` で確認します。

## 先に見る正本

- `app/frontend/entrypoints/application.js`: downstream が current main で実際に register している Stimulus controller
- `vite.config.ts`: downstream が解決している package root / documented direct entrypoint alias
- `docs/関連gem連携調査runbook.md`: host app 採用パターン、release train、representative smoke の正本
- `docs/internal-ui-gem-public-surface-package-verification-matrix.md`: package verification / TypeScript declaration / public API manifest の責務分担
- upstream docs / manifest:
  - `tree_view-rails` の `README.md`、`docs/ja/*`、`config/public_api_manifest.yml`
  - `rails_table_preferences` の `README.md`、`docs/javascript_entrypoints.md`、`docs/javascript_controller.md`
  - `rails_fields_kit` の `README.md`、`doc/public_api.md`、`doc/setup.md`、`doc/events.md`

## JS import / resolver boundary

| gem | docs-portal current import / register | docs-portal Vite resolver | upstream package-root public surface | documented direct entrypoint | downstream 境界 |
| --- | --- | --- | --- | --- | --- |
| `tree_view` | current `application.js` では controller を直接 import / register していない。helper / partial integration が先行する | current `vite.config.ts` には `tree_view` alias はない。JS hook が必要になった issue で alias 追加の要否を判断する | `config/public_api_manifest.yml` の `javascript_package_root.named_exports` が `registerTreeViewControllers`、`TreeViewControllerIdentifiers`、`TreeViewEventNames`、各 controller export を管理する | package-root を入口に扱う。gem 内部の `app/javascript/tree_view/*` path は downstream docs の durable import として書かない | `#903` の release-train 確認口。current downstream 採用を先取りせず、raw event 名 / controller identifier の写経を避ける |
| `rails_table_preferences` | `import { RailsTablePreferencesController } from "rails_table_preferences"` し、`rails-table-preferences` として register する | `rails_table_preferences` と `rails_table_preferences/controller` の alias がある | `docs/javascript_entrypoints.md` が package root named export `RailsTablePreferencesController` を案内する | `rails_table_preferences/controller` も documented。copied-controller / migration note の fallback として扱う | screen issue では current `application.js` と同じ package-root import を基準にする。direct path は fallback / migration note に閉じる |
| `rails_fields_kit` | `import { TomSelectController } from "rails_fields_kit"` し、`rails-fields-kit--tom-select` として register する | `rails_fields_kit` と `rails_fields_kit/tom_select_controller` の alias がある | `doc/public_api.md` が package root named export `TomSelectController` と rendered-field contract helpers を案内する | `rails_fields_kit/tom_select_controller` も documented | new helper / controller helper / JS helper を downstream docs に書く前に、README または `doc/public_api.md` で public export か確認する。未着地 upstream PR の export 名を current main の durable contract として書かない |

## evidence family の読み分け

3 gem はどれも package-root / direct entrypoint を持ちますが、source of truth は同じではありません。横断 issue では次のように記録し、別 repo の確認方式をそのまま移植しません。

| gem | 先に見る evidence family | その evidence で分かること | 代替しないこと |
| --- | --- | --- | --- |
| `rails_table_preferences` | package verifier、`docs/javascript_entrypoints.md`、package-root import smoke | package-root named export / direct controller entrypoint が packaged artifact と docs family に残ること | Markdown preview table の full RTP 採用判断、host app の table key / column policy |
| `tree_view` | public API manifest、package-root registration docs、release / mockup evidence | package-root registration surface と controller identifier / event name の durable entry を確認できること | docs-portal current main で JS controller を採用済みだと書くこと、sidebar / detail tree の host smoke |
| `rails_fields_kit` | public API docs、package contents / package-root smoke、rendered-field helper docs | `TomSelectController` と rendered-field helper family が public surface として確認できること | host app endpoint policy、selected value retention、validation rerender の成功 |

CI success はこの evidence family の guard が通ったことを示します。browser-capable visual evidence、source review、docs-portal representative smoke は別欄に分けて、同じ完了条件として扱いません。

## Issue / PR に残す 1 行メモ

internal UI gem の JS import / resolver を触る issue では、update log に次のどちらを選んだかを 1 行で残します。

```text
- JS import boundary: package-root import を採用。根拠は docs-portal current application.js と upstream public API docs。
```

```text
- JS import boundary: documented direct entrypoint を fallback として参照。根拠は upstream Vite / app/frontend docs と migration lane。
```

`tree_view` は current downstream で controller import が未採用なので、JS hook を追加する issue では `tree_view-rails` の package-root manifest と `#903` の smoke / rollback note を先に確認します。単に sidebar / detail tree の helper・partial・route 文脈だけを直す場合は、JS controller adoption を同じ PR に混ぜません。

package verification、TypeScript declaration、public API manifest を判断材料にする場合は、`docs/internal-ui-gem-public-surface-package-verification-matrix.md` の責務分担を併読し、docs-portal 側で upstream package policy を決めないことを確認します。

## #858 child issue とのつなぎ方

- `#903` (`tree_view`): package-root export は確認口として扱い、downstream 採用の有無はその issue の smoke / rollback note で判断します。
- `#991` / `#921` family (`rails_fields_kit`): current downstream import は package root。helper export や rendered-field contract helper は upstream public API docs で確認してから downstream docs に書きます。
- `#904` (`rails_table_preferences`): current downstream import は package root。direct entrypoint は documented fallback として残し、preview iframe fallback や embedded table 判断は別 issue に切り分けます。

この matrix は、release train の target SHA 判断や Vite alias 実装変更を決める場ではありません。target SHA、representative smoke、rollback target は各 child issue / PR の update log に残します。
