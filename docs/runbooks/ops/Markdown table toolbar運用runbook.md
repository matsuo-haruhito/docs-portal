# Markdown table toolbar 運用 runbook

この文書は、Markdown preview の HTML table に付く current toolbar の読み方をまとめる docs-sync メモです。`docs/版詳細プレビュー・差分・添付確認runbook.md` と `docs/specs/閲覧画面とUI.md` の補助として使い、ここでは新しい viewer 仕様や `rails_table_preferences` の全面統合方針は決めません。

## 判定分類

- code-ahead-of-docs
- docs-missing
- docs-sync

## Source of truth

- `app/frontend/lib/markdown_preview_table_tools.js`
- `spec/frontend/markdown_preview_table_tools_source_spec.rb`
- `docs/版詳細プレビュー・差分・添付確認runbook.md`
- `docs/specs/閲覧画面とUI.md`

## いつ見るか

- `HTML本文を開く` から standalone viewer を開き、Markdown 由来の表を確認するとき
- 表が横長または行数が多く、表内検索やコピーで確認したいとき
- #475 の full `rails_table_preferences` 統合と、current toolbar の境界を読み分けたいとき

## Current support

current `main` では、same-origin の `iframe.site-viewer-frame` 内にある `.portal-table-width-frame` ごとに table toolbar を補助的に差し込みます。cross-origin などで注入できない場合でも、viewer 本文自体は壊さない fallback として扱います。

表ごとに使える主な操作は次のとおりです。

- `検索`: 表内のセル文字列を検索し、一致セルを highlight しながら一致しない行を折りたたむ
- `クリア`: 表内検索語と表示状態を戻す
- `CSV`: 表全体を CSV 形式で clipboard にコピーする
- `Markdown`: 表全体を Markdown table 形式で clipboard にコピーする
- copy status: `コピーしました` / `コピーできませんでした` を表ごとに表示する
- `表示リセット`: table width / column width / sticky header / sticky column の local 表示設定をリセットする

`rails_table_preferences` 用の table key が付いている表では、`列表示` panel が出ることがあります。この panel は列の表示・非表示を保存する補助であり、Markdown 原文、生成済み HTML、文書版、公開状態、権限判定を変更する操作ではありません。

## 読み分け

- table toolbar は iframe 内の Markdown table に対する client-side 補助です。server-side の文書更新、review workflow、承認、監査判断ではありません。
- 検索は表示中 table のセル文字列だけを対象にします。文書全体検索、添付検索、DB 検索、AccessLog 検索とは分けて扱います。
- CSV / Markdown copy は確認・共有のための clipboard 操作です。export file の生成、永続保存、外部送信ではありません。
- `列表示` が出る場合も、admin 一覧の full table preferences と同じ運用判断をそのまま持ち込まないでください。

## Current support として書かないこと

- #475 の full `rails_table_preferences` 統合が完了した、とは書かない
- Markdown 原文や生成済み HTML を toolbar 操作で書き換えられる、とは書かない
- embedded body 側、Docusaurus renderer、Mermaid、Kroki、codeblock action まで同じ helper が扱う、とは書かない
- server-side dry-run、外部 API 送信、正式 review workflow、監査ログ記録を table toolbar の current support として書かない

## 迷ったときの確認順

1. 版詳細全体の見方は `docs/版詳細プレビュー・差分・添付確認runbook.md` を見る
2. viewer / table UX の方針は `docs/specs/閲覧画面とUI.md` の `Markdown table viewer UX` を見る
3. current toolbar の実装境界は `app/frontend/lib/markdown_preview_table_tools.js` と `spec/frontend/markdown_preview_table_tools_source_spec.rb` を見る
4. full `rails_table_preferences` 統合や table preference key の広い判断は #475 を正本として扱う

## 関連

- Refs #2734
- Refs #2765
- Refs #475
