# internal UI gem責務境界matrix

この文書は、`docs-portal` で `tree_view` / `rails_table_preferences` / `rails_fields_kit` を調査・更新するときに、host app 側と upstream gem 側の責務を混ぜないための比較表です。

正本の読み順は [関連gem連携調査runbook](./関連gem連携調査runbook.md) と [フロントエンド操作の方針](../doc/frontend_interaction_policy.md) です。この文書では新しい public API や target SHA は定義せず、`#607` family の screen-by-screen adoption と `#858` family の pinned ref 更新 train が同じ確認観点を参照できるようにします。

## 3 gem の責務境界

| gem | docs-portal 内で担当すること | 担当しないこと | 最初に見る docs-portal 側の場所 | representative smoke |
| --- | --- | --- | --- | --- |
| `tree_view` | 文書ツリー / 詳細ツリーの render state、行描画、開閉、persisted state の組み込みを確認する | 文書 query、権限制御、route、icon、業務ラベル、current node 判定を upstream gem 側の責務にしない | `app/helpers/documents_helper.rb`、`app/helpers/projects_helper.rb`、`app/views/documents/_tree.html.erb`、`app/views/projects/_document_detail_tree.html.erb`、`app/models/concerns/tree_view_state_owner.rb` | `spec/requests/document_tree_regressions_spec.rb` で sidebar tree、detail tree、persisted state、window offset のどこを確認したかを残す |
| `rails_table_preferences` | 一覧の column metadata、表示設定 editor、stable column key、filter / preset、mounted engine 保存の host 側組み込みを確認する | 案件・文書固有の pinned 判断、filter label、業務列の意味を upstream gem 側へ押し戻さない | `app/helpers/admin/document_sets_helper.rb`、`app/views/admin/document_sets/index.html.slim`、`spec/requests/admin_document_sets_index_spec.rb`、`spec/requests/admin_document_sets_spec.rb` | `admin/document_sets` の editor / table / filter / preset / mounted engine save のどこを確認したかを残す |
| `rails_fields_kit` | form helper、Tom Select wiring、selected value、preload / remote search、validation rerender 後の再表示を確認する | field 名、collection、業務 validation、保存時の params contract を upstream gem 側で定義しない | `app/views/admin/document_sets/_form.html.slim`、`app/frontend/entrypoints/application.js`、`vite.config.ts`、`config/initializers/rails_fields_kit.rb`、`spec/requests/admin_document_sets_spec.rb` | `admin/document_sets` form の initial load、selected value 保持、placeholder、invalid rerender のどこを確認したかを残す |

## docs-portal 側に閉じる変更

- 画面ごとの helper 呼び出し、table metadata、form collection、route context、権限制御、業務ラベルを current code に合わせて直す変更
- request spec で host app の truthfulness、stable column key、field 名、再描画後の表示保持を固定する変更
- `admin/document_sets` を代表例に、他 screen へ広げる前の確認順や採用パターンを補う docs 更新
- preview iframe や embedded table のように、current app 側 fallback が正本になっている箇所の境界説明

## upstream gem 側へ押し戻す変更

- documented public export、helper option、controller identifier、event name、installation guide の不足や不整合
- package-root import と direct entrypoint のどちらを案内するかの upstream docs 判断
- `tree_view` の render helper / event、`rails_table_preferences` の engine contract、`rails_fields_kit` の helper option そのものの設計変更
- docs-portal だけで再実装した raw data attribute や ad-hoc JavaScript を upstream public surface として一般化したい場合の判断

## pinned ref 更新 train で残すこと

`#858` family の bump では、3 gem を同じ PR に混ぜません。`1 gem = 1 branch = 1 PR` を基本に、次の 6 点を issue / PR 本文 / review follow-up comment のいずれか 1 箇所へ残します。

- gem 名
- from SHA / tag
- to SHA / tag
- 使った representative smoke
- 確認結果
- rollback target

`#607` family の screen adoption は、revision を動かす train と混ぜず、この matrix の「docs-portal 内で担当すること」と「担当しないこと」を先に見てから個別 screen の docs / spec / UI へ進みます。

## 判断に迷ったとき

- screen adoption なら [関連gem連携調査runbook](./関連gem連携調査runbook.md) の host app 採用パターンを先に読む
- revision を動かすなら同 runbook の release train / verification matrix / update log template を先に読む
- public API や helper behavior の正誤判断が必要なら docs-portal 側で確定せず、upstream issue / PR の確認に戻す
- current code、Issue、既存 docs から判断できない場合は `needs-human` として扱い、docs だけで仕様を作らない
