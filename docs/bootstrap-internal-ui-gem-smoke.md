# Bootstrap CSS 導入時の internal UI gem smoke

このメモは、Bootstrap CSS / Reboot を `docs-portal` に読み込んだ後に、internal UI gem と文書表示の代表 surface が崩れていないかを確認するための最小 smoke です。

基準は PR #1261 merge 後の `main` です。CSS 本体、CDN / SRI、override の設計判断は #1261 に閉じ、このメモでは確認観点と記録先だけを扱います。

## 目的

- Bootstrap Reboot が table、form、typography、document prose に与える影響を、代表 surface で短時間に確認できるようにする
- TreeView、Rails Fields Kit、Rails Table Preferences の host-app 境界を同じ粒度で見る
- smoke 結果の記録先を 1 箇所に寄せ、Issue / PR / runbook に同じ内容を重複させない

## 代表 smoke

| 対象 | 代表 surface | 確認観点 | 既存の近い spec / evidence |
| --- | --- | --- | --- |
| TreeView | sidebar tree: `app/views/documents/_tree.html.erb` | expand / collapse の操作導線、current row の読みやすさ、row indentation と folder / document icon の余白 | `spec/requests/document_tree_regressions_spec.rb` の tree visibility / persisted state / window offset |
| TreeView | detail tree: `app/views/projects/_document_detail_tree.html.erb` | detail side で current document が分かること、toolbar と tree row が詰まりすぎないこと | `spec/requests/document_tree_regressions_spec.rb` |
| Rails Fields Kit | `admin/document_sets` form の `rfk_select` 群 | select / combobox の幅、placeholder、selected value、validation rerender 後の redisplay | `spec/requests/admin_document_sets_spec.rb` の initial load / invalid rerender |
| Rails Table Preferences | `admin/document_sets` index の editor + table | table header / body、stable column key、filter / preset editor、mounted engine save 導線 | `spec/requests/admin_document_sets_index_spec.rb` と `spec/requests/admin_document_sets_spec.rb` |
| Markdown / Docusaurus preview | document prose / rendered HTML preview | 見出し、段落、リンク、code、blockquote、table の affordance が Bootstrap typography / table 初期値で読みづらくなっていないこと | 代表 document の HTML preview または Docusaurus build smoke |

## Reboot 影響の見方

- table: `border-collapse`、cell padding、header weight、striping の前提が host app / gem 側 CSS と衝突していないかを見る
- form: `select` / `input` / `textarea` の height、line-height、focus outline、validation rerender 後の余白を見る
- typography: body font-size、heading margin、paragraph margin、link color が既存の document prose と混ざって読みにくくなっていないかを見る
- TreeView: row の line-height、indent spacer、current row styling、toolbar button の見た目が Bootstrap の button / table 初期値に引っ張られていないかを見る

## 記録先

smoke 結果は、実施した Issue または PR 本文のどちらか 1 箇所にまとめます。runbook には恒常的な確認観点だけを残し、個別実行の通過 / 未実施 / 要 follow-up は重複して書きません。

記録するときは、次の粒度をそろえます。

```text
- 基準: PR #1261 merge 後 main / または対象 branch 名
- viewport: desktop / narrow
- TreeView: sidebar tree / detail tree のどちらを見たか
- Rails Fields Kit: initial load / validation rerender / selected value のどれを見たか
- Rails Table Preferences: editor / filter / preset / engine save のどれを見たか
- Prose: 見出し / table / code / link のどれを見たか
- 結果: 問題なし / follow-up issue 化 / 未確認
```

## 非目標

- Bootstrap JS の導入
- dropdown / tooltip / modal behavior の有効化
- internal UI gem 側の実装変更
- 全画面 visual regression suite の新設
- host app 全体の design system 再設計
- Docusaurus content / markdown rendering plugin の仕様変更
