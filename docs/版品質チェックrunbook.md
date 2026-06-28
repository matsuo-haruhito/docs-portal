# 版品質チェック runbook

この文書は、internal user が `DocumentVersion` の品質チェック画面を読むときの運用メモです。`docs/版詳細プレビュー・差分・添付確認runbook.md` の `品質チェック` 導線から入った後、HTML / JSON / Markdown response を read-only evidence として確認する範囲だけを扱います。

新しい品質判定 policy、通知、ack、saved report、品質チェック job 化、JSON / Markdown schema の変更はここでは定義しません。品質チェック結果を公開承認 gate や正式レビュー承認 workflow の状態として読む必要が出た場合は、[正式レビュー承認 workflow 境界メモ](./正式レビュー承認workflow境界メモ.md) に戻し、workflow 採否や承認 policy の人間判断として扱います。

## 先に見るもの

1. 版詳細画面で `プレビュー状態`、`比較対象`、`変更サマリ`、`添付・元ファイル` を確認する
2. build warning、metadata、添付構成などを internal 観点で切り分けたい場合だけ `品質チェック` へ進む
3. external user 向けの通常確認では、この画面を前提にしない

関連する入口:

- [版詳細プレビュー・差分・添付確認 runbook](./版詳細プレビュー・差分・添付確認runbook.md)
- [閲覧画面とUI](./specs/閲覧画面とUI.md)
- [Microsoft Graph接続とOffice preview](./Microsoft%20Graph%E6%8E%A5%E7%B6%9A%E3%81%A8Office%20preview.md)
- [正式レビュー承認 workflow 境界メモ](./正式レビュー承認workflow境界メモ.md)

## HTML 画面の読み方

品質チェック画面の先頭では、版の `判定` と severity count を見ます。

- `判定: pass`: error がない状態。warning や info が残っている場合は、公開前確認や handoff の観点で必要なものだけ読む
- `判定: fail`: error がある状態。下の check table で error 行の `key`、`message`、`detail` を優先して確認する
- `error`: 公開前に原因確認が必要な項目
- `warning`: 表示や運用上の注意。Preview block に抜粋されることがある
- `info`: 参考情報。単独で品質失敗扱いにしない

`fail` は error count がある状態として読み、warning / info は自動的な差し戻しや通知済み状態とは扱いません。`pass` も承認済みや公開許可済みを意味せず、確認時点の read-only evidence としてだけ扱います。

## Preview block

`Preview` block は、`rendered_site` と `preview_build_status` の warning / error だけを抜粋する補助表示です。

- rendered site や build status の warning / error を先に見るための近道として使う
- すべての check を網羅する場所ではない
- 全件確認が必要な場合は、下の check table を正本として見る
- Preview block が空でも、JSON / Markdown export や check table の確認が不要になるわけではない

Preview block の detail に build path や source path が出る場合でも、raw secret、本文 full text、添付 full metadata の確認入口として扱いません。

## Check table

下の table は、品質チェック結果を HTML 画面上で確認する一覧です。`severity` と `key` の filter はこの table だけに適用され、Preview block や JSON / Markdown export の内容は絞り込まれません。

| 列 | 読み方 |
| --- | --- |
| `severity` | `error` / `warning` / `info` の分類。まず error を優先して読む |
| `key` | check の種類。`rendered_site`、`preview_build_status`、`document_files` などの切り分け単位 |
| `message` | 人が読む短い説明 |
| `detail` | 追加情報。空の場合は `-` と表示される |

filter の読み方:

- `severity` は `error` / `warning` / `info`、`key` は現在の check 一覧に存在する key だけを使う
- unsupported な `severity` や `key` は採用されず、該当 filter なしの全件側へ戻る
- `表示中: X件 / 全Y件` は HTML table の表示件数であり、品質チェック結果全体の件数は `全Y件` と JSON / Markdown export を正本にする
- `現在の filter に一致する check はありません。` は table 表示だけの 0 件であり、品質チェック結果そのものが空になったことを意味しない

check table と filter は read-only の結果確認です。この画面で品質チェック結果、版、添付、公開状態を変更する操作は行いません。

## JSON / Markdown export

画面上部の `JSON` / `Markdown` link は、handoff や evidence 用の read-only export です。

- JSON は `valid`、`document_version`、`summary`、`checks` の代表 shape を持つ machine-readable evidence として読む
- Markdown は PR comment、運用 handoff、調査メモに貼りやすい summary として読む
- どちらも品質チェック結果を変更しない
- HTML table filter の `severity` / `key` は export payload には適用されない。filter 中でも export は全件の read-only evidence として扱う
- external user は HTML / JSON / Markdown のいずれも利用できない internal-only 境界として扱う

JSON / Markdown export の schema 変更、saved report 化、通知連携、ack workflow、品質チェック job 化は current support として書かないでください。

## 迷ったときの切り分け

- 本文 preview の状態を先に見たい: 版詳細画面の `プレビュー状態` を見る
- build warning / rendered site warning だけ先に拾いたい: 品質チェック画面の `Preview` block を見る
- error / warning / info の全件を確認したい: check table を見る。HTML 上で見たい行だけに絞る場合は `severity` / `key` filter を使う
- PR や handoff に結果を渡したい: `JSON` または `Markdown` export を使う。HTML table filter 中でも export は全件 evidence として読む
- external user の閲覧可否や添付 download 権限を確認したい: 品質チェックではなく、版詳細 / 文書詳細 / 権限 runbook に戻る
- 品質チェックを公開承認 gate、通知、ack、差し戻し workflow として使いたい: この runbook では決めず、[正式レビュー承認 workflow 境界メモ](./正式レビュー承認workflow境界メモ.md) に戻して human decision として扱う

## 非目標

- `DocumentVersionQualityChecker` の判定ロジック変更
- JSON / Markdown response schema の再定義
- HTML table のさらなる filter、saved filter、saved report、通知、ack
- 品質チェックの background job 化
- external user 向け導線化
- 版詳細 runbook 全体の再編
- 品質チェック結果を正式レビュー承認 workflow や公開承認 gate として扱うこと
