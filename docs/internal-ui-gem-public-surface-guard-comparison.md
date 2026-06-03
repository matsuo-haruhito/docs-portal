# internal UI gem public surface guard comparison

この文書は、`docs-portal` で `tree_view` / `rails_table_preferences` / `rails_fields_kit` の release train evidence を読むときに、3 gem の public surface guard 方針を 1 つの表で見比べるための入口です。

`#858` 配下の pinned ref bump や downstream smoke では、upstream evidence と docs-portal 側の representative smoke を分けて記録します。この文書は比較材料を整理するだけで、3 gem の public API 方針、manifest 採用、package verifier、TypeScript declaration、target SHA は決めません。

## 使うタイミング

- `#858` の child issue で、bump 前に upstream evidence と downstream smoke を分けたいとき
- TreeView 型 manifest を他 gem にコピーすべきか、docs / package verifier / visual evidence で十分かを見比べたいとき
- review follow-up で、upstream docs の未着地 proposal を current support として書いていないか確認したいとき
- `docs/関連gem連携調査runbook.md`、`docs/internal-ui-gem-adoption-evidence-map.md`、`docs/internal-ui-gem-public-surface-guard-playbook.md` のどれを先に読むか迷ったとき

## 横断比較表

| 比較軸 | `tree_view` | `rails_table_preferences` | `rails_fields_kit` | docs-portal での読み方 |
| --- | --- | --- | --- | --- |
| public surface の正本 | `config/public_api_manifest.yml` を manifest-backed source として読む。Ruby module methods、helper methods、toolbar actions、grouped option keys、JavaScript package-root exports、controller registrations、event names / detail keys が対象 | README と `docs/index.md` family を docs-backed source として読む。helper、mounted JSON API、JavaScript entrypoints、manual QA、release checks、package verification を合わせて確認する | `doc/public_api.md` を public API docs-backed source として読む。Ruby entrypoint、configuration、FormBuilder helpers、controller helpers、JavaScript exports、Stimulus values / events を確認する | まず current merged docs / manifest を見る。open PR や proposal の export 名、event detail、helper option は current support として書かない |
| Ruby helper / controller helper | manifest にある helper methods / option keys を確認する。route、permission、icon、row label は host app 側責務 | table helper、mounted engine、column metadata helper は docs family と current helper source を照合する | `rfk_*` helpers、controller helper、metadata adapters は `doc/public_api.md` と field / controller docs を照合する | host app 固有の params、authorization、query、business copy は upstream gem の contract にしない |
| JavaScript package-root export | manifest の `javascript_package_root.named_exports` を見る。`registerTreeViewControllers`、controller identifiers、event names などは manifest / docs にあるものだけを使う | package root `RailsTablePreferencesController` を current downstream default として読む。`rails_table_preferences/controller` は documented fallback / migration lane | package root `TomSelectController` を current downstream default として読む。`rails_fields_kit/tom_select_controller` は documented fallback | `app/frontend/entrypoints/application.js` と `vite.config.ts` の current wiring を downstream evidence にする。gem 内部 path を durable import にしない |
| event names / detail keys | manifest-backed guard が向く surface。event detail keys の proposal は upstream で確定してから downstream docs へ入れる | table preference controller event や detail shape は upstream docs / package verifier にある current surface だけを参照する | `doc/events.md` と `doc/public_api.md` にある current events を参照する | raw string の写経や proposal 名の先取りを避け、必要なら upstream issue へ戻す |
| generator output / copied controller | setup generator / copied controller が manifest または public docs にあるかを確認する | copied controller / direct controller files は package verifier evidence として読む。current docs-portal default は package-root import | setup note / generated wiring / package contents guard を確認する | generator output は downstream adoption 成功の証拠ではない。host app で実際に wiring / smoke を分けて確認する |
| package verifier / package contents | manifest、package-root export、built gem contents を upstream package-sensitive guard で見る | package root / direct controller / `.d.ts` / package verifier / release checklist を upstream evidence として見る | package-root export、generated setup note、package contents spec、JS smoke を upstream evidence として見る | package verifier は upstream artifact の確認材料。docs-portal 側で upstream verifier policy を再定義しない |
| visual reference / sample app evidence | review gallery / mockups は tree behavior の視覚 evidence として見るが、docs-portal route や permission の代替にしない | visual overview / demo screen generator は table behavior の evidence。host table columns / filters は downstream smoke で見る | visual reference inventory / sample app checklist/results は field helper evidence。host form params / validation は downstream smoke で見る | visual evidence は screenshot や manual QA の完全な代替ではない。未確認 viewport / 操作は未確認として残す |
| downstream representative smoke | sidebar tree、detail tree、persisted state、selection、window offset | `admin/document_sets` の editor、stable column key、filter / preset、mounted engine save | `admin/document_sets` form の preload、placeholder、selected value、invalid rerender、Tom Select wiring | upstream evidence と同じ PR body に書いてもよいが、責務は分ける。upstream docs の完了は host app smoke 成功を意味しない |
| manifest-backed guard が向く surface | package-root exports、event names、detail keys、helper / option inventory のように drift すると adopter が壊れる surface | current support では manifest を正本にしない。docs-backed / package verifier-backed で十分な surface が多い | current support では manifest を正本にしない。public API docs-backed / package contents-backed で十分な surface が多い | TreeView 型 manifest は、surface inventory が多く drift しやすい場合の選択肢。3 gem へ機械的にコピーしない |
| needs-human に戻す条件 | manifest にない hook を使いたい、proposal event detail を current support として書く必要がある | `#789` の known-good revision、TypeScript declaration、preview table 採用判断を先取りする必要がある | 未 merge の helper export / setup policy / visual inventory を current support として扱う必要がある | public API 方針、target SHA、broad bump、Gemfile / lockfile 更新、CI workflow、upstream docs 実装はこの docs では決めない |

## evidence を残すときの最小テンプレート

```text
- upstream evidence:
  - public surface source: <manifest / public_api.md / README + docs index>
  - package evidence: <package-root export / direct entrypoint / package verifier / release checklist>
  - visual or sample evidence: <mockup / visual reference / sample checklist, if used>
- downstream docs-portal smoke:
  - host app surface: <sidebar tree / admin document_sets / target screen>
  - spec or manual evidence: <request spec / source spec / CI / manual note>
  - responsibility split: <what stays host-app-owned>
- unresolved / human gate:
  - <open proposal / target SHA / known-good revision / screenshot pending>
```

## 関連 docs の読み分け

- [関連 gem 連携調査 runbook](./関連gem連携調査runbook.md): 調査開始時に見る host app 採用パターン、release train、representative smoke の入口
- [internal UI gem adoption evidence map](./internal-ui-gem-adoption-evidence-map.md): docs-portal 側の代表画面、upstream evidence、確認順、rollback note の入口
- [internal UI gem public surface guard playbook](./internal-ui-gem-public-surface-guard-playbook.md): public surface、docs drift guard、package evidence、adoption readiness を同じ粒度で見る入口
- [internal UI gem public surface / package verification matrix](./internal-ui-gem-public-surface-package-verification-matrix.md): package-root export、direct entrypoint、TypeScript declaration、manifest、package verification の境界
- [internal gem release train smoke notes](./internal-gem-release-train-smoke.md): pinned ref 更新時の target revision、representative smoke、rollback note の記録形式

## 境界

- この文書は docs-only の比較表です。
- `Gemfile` / `Gemfile.lock`、runtime code、spec、CI workflow、upstream gem docs、manifest、package verifier は変更しません。
- 3 gem の public API 方針を統一する結論は書きません。
- upstream open PR / proposal は current support として書かず、`確認待ち` または `merge 後に再確認` として扱います。
- `#858` の target SHA、known-good revision、representative smoke 結果、rollback target は各 child issue / PR の update log を正本にします。
