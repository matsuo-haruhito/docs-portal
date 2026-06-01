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
