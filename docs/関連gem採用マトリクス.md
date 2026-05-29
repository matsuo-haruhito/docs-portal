# 関連 gem 採用マトリクス

この文書は、`docs-portal` が host app として `tree_view` / `rails_table_preferences` / `rails_fields_kit` をどの画面で採用しているかを横断で確認するための入口です。

方針の正本は [フロントエンド操作の方針](../doc/frontend_interaction_policy.md)、調査時に読むファイルと upstream docs の入口は [関連 gem 連携調査 runbook](./関連gem連携調査runbook.md) です。この文書では、代表画面、gem 側責務、host app 側責務、確認すべき contract を 1 表に寄せます。

## 読み方

- `gem responsibility` は upstream gem が持つべき責務です。
- `host app responsibility` は `docs-portal` の controller / helper / view / CSS / spec で確認すべき責務です。
- Markdown preview table は current app 側 fallback として扱います。`rails_table_preferences` 採用済みとは読まず、方針判断は `#475` 側に残します。
- 実際の gem bump、target SHA 決定、system spec 追加はこの文書では行いません。必要な場合は個別 issue / PR に分けます。

## JavaScript public surface の比較

この表は 3 gem の API を同じ名前へそろえるためのものではありません。`docs-portal` から見える package-root import、controller import、hook / event / helper export を比較し、どの repo の正本を読みに行くかを決めるための用語表です。

| gem / surface | package-root import | controller / direct entrypoint | hook / event / rendered contract | host app で直接持つ責務 | 参照先 |
| --- | --- | --- | --- | --- | --- |
| `tree_view` | host app の current `application.js` では package-root controller import を常用していない。Rails helper / partial / render state が主 surface | JavaScript controller 登録が必要なときは upstream installation / public API docs を確認する | documented hook / event / selection / lazy-loading surface は TreeView の DOM interaction contract。host app はこれを前提に文書 query や action を組み立てる | 文書 node、folder node、権限、route、business action、lazy loading query、selection 後の業務処理 | [`tree_view-rails` README](https://github.com/matsuo-haruhito/tree_view-rails/blob/main/README.md), [`tree_view` installation](https://github.com/matsuo-haruhito/tree_view-rails/blob/main/docs/en/installation.md), `tree_view-rails#583`, `#664`, `#665`, `#706` |
| `rails_table_preferences` | `import { RailsTablePreferencesController } from "rails_table_preferences"` を package-root export として使える | `rails_table_preferences/controller` は documented direct entrypoint。copied-controller migration や Vite alias 検証時に読む | table settings editor、column metadata、filter / preset、mounted engine API が主 surface。raw DOM hook を host app で勝手に増やすより stable column key と helper metadata を先に見る | `table_key`、列 label / width / pinned / filter、row action、画面固有の検索や export、Markdown preview table を採用済み扱いにしない判断 | [`rails_table_preferences` README](https://github.com/matsuo-haruhito/rails_table_preferences/blob/main/README.md), [JavaScript entrypoints](https://github.com/matsuo-haruhito/rails_table_preferences/blob/main/docs/javascript_entrypoints.md), [Resource table adapters](https://github.com/matsuo-haruhito/rails_table_preferences/blob/main/docs/resource_tables.md), `docs-portal#789`, `#904` |
| `rails_fields_kit` | `import { TomSelectController } from "rails_fields_kit"` を package-root export として使える | `rails_fields_kit/tom_select_controller` は documented direct entrypoint。Vite alias や importmap pin の検証時に読む | rendered contract helper export と Stimulus events は field helper の再描画 / remote search / selected preload を読むための surface。`tree_view` の tree hook と同一概念ではない | field 名、params shape、collection、selected value、placeholder、validation rerender、remote endpoint、Tom Select CSS / dependency wiring | [`rails_fields_kit` README](https://github.com/matsuo-haruhito/rails_fields_kit/blob/main/README.md), [Public API](https://github.com/matsuo-haruhito/rails_fields_kit/blob/main/doc/public_api.md), [Events](https://github.com/matsuo-haruhito/rails_fields_kit/blob/main/doc/events.md), `rails_fields_kit#364`, `#297`, `#292` |

使い分けの目安は次です。

- package-root export は upstream README / public API が stable として案内しているときの host app default にします。
- direct entrypoint は documented fallback、copied-controller migration、Vite / importmap の alias 検証で必要なときに参照します。
- raw DOM hook を host app に直接書く前に、upstream gem が公開している helper、event、column metadata、rendered contract で表現できるかを確認します。
- upstream issue にしかない API 候補は、docs-portal 側で実装済みのように書かず、参照導線と検討中の位置づけに留めます。

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