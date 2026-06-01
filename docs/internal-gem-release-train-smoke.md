# Internal gem release train smoke notes

この文書は `docs-portal` で internal UI gem の pinned ref を更新するときに、target revision、代表 smoke、rollback note を同じ粒度で残すための運用メモです。

対象は `#858` 配下の child lane です。ここでは gem ref の更新や画面 redesign は行わず、次の dependency bump PR が小さく進められるように、確認面と記録形式を固定します。

## 対象 lane

| gem | child issue | current resolved revision | target revision | rollback target | first smoke surface |
| --- | --- | --- | --- | --- | --- |
| `tree_view` | `#903` | `9c538f9ee7946fa5af24f15c99402a0431677303` | child PR で決める。upstream の selection / public hook lane 全体をここへ混ぜない | `9c538f9ee7946fa5af24f15c99402a0431677303` | sidebar tree と detail tree |
| `rails_fields_kit` | `#991` | `0c29bb935a1df3e61add860a966a2fc7ea586b1a` | child PR で決める。helper-export family や screen-by-screen adoption は混ぜない | `0c29bb935a1df3e61add860a966a2fc7ea586b1a` | `admin/document_sets` form |
| `rails_table_preferences` | `#904` | `b3f1a9d6eb46aefe568c637396fab63151aef322` | child PR で決める。`#789` の known-good revision 判断をここで先取りしない | `b3f1a9d6eb46aefe568c637396fab63151aef322` | `admin/document_sets` の editor / filter / preset と mounted engine save |

`rails_table_preferences` の known-good revision 判断は `#789` に残します。`#789` は human gate が明記されているため、この smoke note では target revision を決めません。

## current snapshot (2026-06-01)

この snapshot は dependency bump の target SHA を決めるものではありません。PR 実行時点で `docs-portal` の current pin から upstream `main` までを再計測し、差分数や representative signal が古くなっていないかを確認します。

| 優先順 | gem | current pin | upstream target | current distance | representative upstream signal | downstream source | rollback note |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | `rails_fields_kit` | `0c29bb935a1df3e61add860a966a2fc7ea586b1a` | `matsuo-haruhito/rails_fields_kit@main` | `main` is 203 commits ahead, 0 behind | `rails_fields_kit#525` merged: package exports smoke と public API docs drift guard | bump issue `#1300`; smoke lane `#991` | rollback target は current pin。`tree_view` / `rails_table_preferences` bump を混ぜない |
| 2 | `tree_view` | `9c538f9ee7946fa5af24f15c99402a0431677303` | `matsuo-haruhito/tree_view-rails@main` | `main` is 359 commits ahead, 0 behind | `tree_view-rails#987` merged: direction-sensitive CSS guard | bump issue `#1301`; smoke lane `#903` | rollback target は current pin。sidebar tree / detail tree smoke を記録する |
| human-gated | `rails_table_preferences` | `b3f1a9d6eb46aefe568c637396fab63151aef322` | `matsuo-haruhito/rails_table_preferences@main` | `main` is 451 commits ahead, 0 behind | `rails_table_preferences#581` open: resource table row hook; `docs-portal#1499` merged: smoke note | human-gated bump issue `#789`; smoke lane `#904` | rollback target は current pin。`#789` の known-good revision 判断を先取りしない |

再計測時の確認:

- `Gemfile` と `Gemfile.lock` の current pin がこの表と一致するかを先に確認する
- upstream `main` の ahead count は絶対値として扱わず、PR 作成直前の compare 結果で置き換える
- release train の優先順は `rails_fields_kit` -> `tree_view` -> `rails_table_preferences` を基本にする
- ただし current CI、mergeability、`#789` の human gate、representative smoke の状態で実行可否を再判断する
- この snapshot 更新だけでは `Gemfile` / `Gemfile.lock` を変更しない

## upstream PR readiness snapshot

作業直前の上流 PR の merge / review / branch refresh 状態は、`docs/internal-ui-gem-upstream-readiness-snapshot.md` を先に確認します。この snapshot は target SHA を決める正本ではなく、`rails_fields_kit` / `tree_view-rails` / `rails_table_preferences` の open PR を「含めたいもの」「含めなくてよいもの」「human review 待ち」に分けるための時点メモです。

- snapshot は時点依存なので、bump PR 作成時に上流 `main`、candidate PR、CI、mergeability を再確認する
- 未マージの docs/design PR (`#1510` や `#1620`) を前提にした link や target 判断は避ける
- public API / helper signature / bundled UI behavior を変える上流 PRは、`#1300` / `#1301` / `#789` の child lane で人間判断に戻す

## dependency bump human handoff

`#1300` / `#1301` / `#789` のような dependency bump lane は、作業直前の upstream 状態と lockfile 再生成結果を正本にします。エージェント環境で checkout、Bundler、代表 smoke を安全に実行できない場合は、`Gemfile.lock` の SHA 行だけを connector 手編集して完了扱いにしません。

人間が実行する最小手順:

1. 対象 gem を 1 つだけ選び、対応する child issue と current pin を確認する。
2. upstream `main`、candidate PR、CI、release notes / README を作業直前に再確認し、target SHA を決める。
3. `Gemfile` と `Gemfile.lock` を Bundler で更新する。`Gemfile.lock` は `bundle install` / `bundle lock` などの生成結果を正とし、SHA 行だけの手編集で代替しない。
4. この文書の representative smoke を対象 gem だけ実行し、未確認 surface があれば未確認として明記する。
5. PR 本文または issue comment に `from`、`to`、representative smoke、result、rollback target を 1 箇所へ記録する。

PR に混ぜないもの:

- 複数 gem の ref 更新
- upstream gem 側の public API / setup policy 変更
- host app の画面 redesign や business spec 変更
- known-good revision 判断が残る `#789` の先取り

エージェントが止める条件:

- GitHub checkout / fetch、Bundler、または representative smoke を実行できず、lockfile と smoke 結果を正本として確認できない
- target SHA の選定に upstream issue / PR / CI の人間判断が必要
- smoke failure の原因が business spec、認可、DB schema、外部 API、UI redesign に広がる
- `#1552` の current queue sync と矛盾する target、または未解決の release train human gate を上書きする必要がある

止める場合は、対象 child issue に次を短く残します。

- どの gem / child issue で止めたか
- 最後に確認した current pin と candidate target
- 実行できなかった作業（checkout、Bundler、smoke など）
- 再開条件（人間が target SHA、Bundler lockfile、代表 smoke、rollback target を確認すること）

## tree_view representative smoke

`tree_view` の更新では、文書ツリーの見た目だけでなく route context と persisted state を確認します。

確認する surface:

- `app/views/documents/_tree.html.erb`
- `app/views/projects/_document_detail_tree.html.erb`
- `app/helpers/documents_helper.rb`
- `app/helpers/projects_helper.rb`
- `app/models/concerns/tree_view_state_owner.rb`
- `spec/requests/document_tree_regressions_spec.rb`

最小 smoke:

- sidebar tree で expand / collapse が `DocumentsHelper::DOCUMENT_TREE_INSTANCE_KEY` の state に保存される
- detail tree で folder expand / collapse が detail 側の key と route context を壊さない
- tree refresh の Turbo Stream が current row / visible document kind / toolbar を維持する
- window offset や persisted state の regression spec が既存の期待を保つ

記録時の注意:

- sidebar tree だけを確認した場合は、detail tree は未確認として書く
- upstream public hook / selection contract の再設計は `docs-portal` 側で決めない
- route、権限、表示対象文書の業務条件は gem 側へ押し戻さない

## rails_fields_kit representative smoke

`rails_fields_kit` の更新では、Tom Select helper の見た目だけでなく selected value と invalid rerender を確認します。

確認する surface:

- `app/views/admin/document_sets/_form.html.slim`
- `app/frontend/entrypoints/application.js`
- `vite.config.ts`
- `config/initializers/rails_fields_kit.rb`
- `app/frontend/lib/tom_select_fields.js`
- `spec/requests/admin_document_sets_spec.rb`

最小 smoke:

- `admin/document_sets` form の representative select が initial load で描画される
- invalid create rerender 後も同じ field 名と selected value が残る
- placeholder / allow_clear / set_type / visibility_policy の current contract が維持される
- controller registration、Vite alias、initializer、no-op shim の責務が app 側へ戻っていない

記録時の注意:

- current main の first smoke は preload / collection path を正本にする
- remote search を変える issue では、対象 endpoint と selected value を追加で確認する
- helper-export family や screen-by-screen adoption は別 issue / PR に分ける

## rails_table_preferences representative smoke

`rails_table_preferences` の更新では、一覧の見た目だけでなく table key、stable column key、filter / preset、mounted engine save の組み合わせを確認します。

確認する surface:

- `app/views/admin/document_sets/index.html.slim`
- `app/helpers/admin/document_sets_helper.rb`
- `config/initializers/rails_table_preferences.rb`
- `app/frontend/entrypoints/application.js`
- `vite.config.ts`
- `spec/requests/admin_document_sets_index_spec.rb`
- `spec/requests/admin_document_sets_spec.rb`

最小 smoke:

- `admin/document_sets` 一覧で table preferences editor と table が同じ `table_key` を使う
- `project` や `actions` などの pinned / filter / preset column metadata が helper 側の current contract を保つ
- table の `th` / `td` に stable column key が残り、saved order や hidden column の対象が drift しない
- mounted engine API を通じた設定保存と一覧再表示が current route / filter / action link を壊さない

記録時の注意:

- `#789` の known-good revision 判断が未完了の間は、target SHA を推測して broad bump しない
- `rails_fields_kit` と同じ `admin/document_sets` surface を使うが、RFK の field helper smoke と RTP の table metadata smoke を混同しない
- Markdown preview table fallback、embedded table rollout、screen-by-screen adoption、host app redesign は別 issue / PR に分ける

## update log template

実際に pinned ref を動かした PR では、PR 本文または issue comment のどちらか 1 箇所に次の形式で残します。同じ内容を複数箇所へ重複させません。

```text
- gem: <tree_view | rails_fields_kit | rails_table_preferences>
- issue: #<child issue>
- from: <current resolved SHA or tag>
- to: <target SHA or tag>
- representative smoke:
  - <docs-portal surface or spec name>
  - <manual screen, request spec, or CI job used>
- result:
  - <passed / failed / skipped with reason>
  - follow-up: <none or issue number>
- rollback target:
  - <SHA or tag to restore>
```

## boundaries

- 1 gem の pinned ref 更新は 1 branch / 1 PR を基本にする
- `tree_view`、`rails_fields_kit`、`rails_table_preferences` を同じ PR で同時に上げない
- target SHA は upstream issue / PR / README / docs を読んで child PR 側で決める
- smoke failure が app helper、partial、route、Turbo Stream、field param に閉じる場合は `docs-portal` 側 issue として扱う
- public API、setup docs、Stimulus 登録例、Vite alias 前提の不足は upstream 側 issue / docs を先に確認する
- business spec、認可、DB schema、外部 API、UI redesign が必要になった場合は `needs-human` として止める
- checkout、Bundler、representative smoke のいずれかを実行できない環境では、`Gemfile.lock` の connector 手編集だけで bump PR を作らず、対象 issue に停止理由と再開条件を残す