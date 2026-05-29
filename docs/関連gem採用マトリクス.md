# 関連 gem 採用マトリクス

この文書は、`docs-portal` が host app として `tree_view` / `rails_table_preferences` / `rails_fields_kit` をどの画面で採用しているかを横断で確認するための入口です。

方針の正本は [フロントエンド操作の方針](../doc/frontend_interaction_policy.md)、調査時に読むファイルと upstream docs の入口は [関連 gem 連携調査 runbook](./関連gem連携調査runbook.md) です。この文書では、代表画面、gem 側責務、host app 側責務、確認すべき contract を 1 表に寄せます。

## 読み方

- `gem responsibility` は upstream gem が持つべき責務です。
- `host app responsibility` は `docs-portal` の controller / helper / view / CSS / spec で確認すべき責務です。
- Markdown preview table は current app 側 fallback として扱います。`rails_table_preferences` 採用済みとは読まず、方針判断は `#475` 側に残します。
- 実際の gem bump、target SHA 決定、system spec 追加はこの文書では行いません。必要な場合は個別 issue / PR に分けます。

## 統合採用マトリクス

| 代表 surface | 主な gem / fallback | gem responsibility | host app responsibility | 代表ファイル / 画面 | 関連 docs / issue |
| --- | --- | --- | --- | --- | --- |
| 文書 sidebar tree | `tree_view` | tree row / render state / toolbar helper / 開閉 UI の基盤 | 文書 query、権限制御、folder node、icon 判定、current node、表示可能 HTML の判定 | `app/helpers/documents_helper.rb`, `app/views/documents/_tree.html.erb` | [関連 gem 連携調査 runbook](./関連gem連携調査runbook.md), `tree_view-rails` README / docs, `docs-portal#473`, `docs-portal#471` |
| 文書詳細 tree | `tree_view` | 詳細画面でも使う tree render / row 表示 contract | project context、文書詳細 route、detail 側の folder node と persisted state | `app/helpers/projects_helper.rb`, `app/views/projects/_document_detail_tree.html.erb`, `app/controllers/projects_controller.rb` | [関連 gem 連携調査 runbook](./関連gem連携調査runbook.md), `docs-portal#903` |
| 管理系の通常 Rails table | `rails_table_preferences` | table settings editor、column metadata、filter / preset、mounted engine の保存 API | `table_key`、列定義、stable column key、row action、画面固有の pinned / label / filter 判断 | `app/views/admin/document_sets/index.html.slim`, `app/helpers/admin/document_sets_helper.rb`, `spec/requests/admin_document_sets_index_spec.rb` | [関連 gem 連携調査 runbook](./関連gem連携調査runbook.md), `rails_table_preferences` README / docs, `docs-portal#904`, `docs-portal#789` |
| Markdown preview table | app 側 fallback | まだ `rails_table_preferences` 採用済み surface とは扱わない | Docusaurus / Markdown 由来 HTML table の表示、注釈、preview 文脈、将来 `rails_table_preferences` に寄せるかの判断材料 | `docs/版詳細プレビュー・差分・添付確認runbook.md`, preview 関連 view / helper | [フロントエンド操作の方針](../doc/frontend_interaction_policy.md), `docs-portal#475` |
| 検索可能 select / tag / autocomplete | `rails_fields_kit` | `rfk_*` helper、Tom Select controller、events、configuration、table metadata 連携 | 画面ごとの field 名、collection、selected value、placeholder、validation rerender、Turbo 再訪後の表示 | `app/views/admin/document_sets/_form.html.slim`, `config/initializers/rails_fields_kit.rb`, `spec/requests/admin_document_sets_spec.rb` | [関連 gem 連携調査 runbook](./関連gem連携調査runbook.md), `rails_fields_kit` README / docs, `docs-portal#921`, `docs-portal#478` |
| frontend entrypoint / Vite wiring | `rails_table_preferences` / `rails_fields_kit` | package-root export と documented direct entrypoint の提供 | `application.js` の controller 登録、`vite.config.ts` の alias、app 側互換 shim が責務を持ちすぎていないこと | `app/frontend/entrypoints/application.js`, `vite.config.ts`, `app/frontend/lib/tom_select_fields.js` | [フロントエンド操作の方針](../doc/frontend_interaction_policy.md), [関連 gem 連携調査 runbook](./関連gem連携調査runbook.md) |

## 代表 smoke の使い分け

| gem / fallback | 最初に見る surface | 最小 evidence | 追加確認が必要になる条件 |
| --- | --- | --- | --- |
| `tree_view` | sidebar tree と文書詳細 tree | tree visibility、persisted state、window offset、icon / folder node の代表例 | 文書 query、権限、route context、icon fallback、refresh path が変わるとき |
| `rails_table_preferences` | `admin/document_sets` の editor + table | editor 描画、stable column key、filter / preset、mounted engine save | column metadata、host app 固有 filter、embedded table、known-good revision 判断を触るとき |
| `rails_fields_kit` | `admin/document_sets` form の `rfk_select` 群 | initial load、selected value 保持、placeholder、invalid rerender | remote search、create flow、events、controller helper、public import path を触るとき |
| Markdown preview table fallback | 版詳細 preview / 差分 / 添付確認 | app 側 fallback として表示・注釈・preview 文脈が崩れていないこと | `rails_table_preferences` へ寄せる範囲を決める必要があるとき。これは `needs-human` または個別 issue で扱う |

## issue triage での切り分け

- app 側に寄せる: route、権限、文書 query、helper、partial、table key、field params、Turbo 導線、CSS が原因のとき。
- upstream docs / issue も確認する: public API、Vite alias、Stimulus 登録例、package-root export、events、table adapter の説明不足が原因のとき。
- `needs-human` にする: Markdown preview table をどこまで `rails_table_preferences` に寄せるか、known-good revision をどこに置くか、gem API を追加するかの判断が必要なとき。

## update log に残す最小項目

関連 gem の更新や smoke 結果を issue / PR に残す場合は、次の 6 点だけを 1 セットにします。

```text
- gem: <tree_view | rails_table_preferences | rails_fields_kit>
- from: <current SHA or tag>
- to: <target SHA or tag>
- representative smoke: <見た画面 / spec / evidence>
- result: <維持できた contract / follow-up>
- rollback target: <戻す SHA or tag>
```

同じ更新の履歴を issue、PR 本文、review comment に重複して残さず、次に追う場所を 1 つに固定してください。