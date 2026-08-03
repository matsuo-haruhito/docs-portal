# search index rebuild 履歴境界メモ

このメモは issue `#4586` / `#4746` の first slice として、Docusaurus site build 履歴とは別に search index rebuild 履歴を検討する前提を棚卸しするものです。

`docs/ToDo.md` の「生成ファイル run 履歴を別 build / import 履歴へ広げる前提」は、このメモでは search index rebuild だけに固定して読みます。Docusaurus site build は [site build 実行履歴保存境界メモ](./site-build実行履歴保存境界メモ.md)、Git連携 run は [Git連携 run 履歴保存境界メモ](./Git連携run履歴保存境界メモ.md) を正本にし、3 surface を同時に実装する候補として扱いません。

current repo では、search index rebuild 専用の controller action、service、Rake task、GitHub Actions job はまだ current support として確認していません。確認した current surface は `.github/workflows/build-docs.yml` の Docusaurus build / manifest / artifact archive、`GeneratedFiles::SiteBuildArtifactRunRecorder`、および生成ファイル実行履歴 runbook の `docs-site` artifact evidence です。したがって、この first slice では search index rebuild 実装や `GeneratedFileRun` への保存実装を追加せず、後続で具体 surface が決まったときの保存境界だけを固定します。

## site build 履歴との責務差

Docusaurus site build 履歴は、`docs-site` artifact と `publish/manifest/publish.json` 由来の read-only evidence です。対象は build artifact の出自確認であり、artifact 本体、manifest 全文、CI log 全文、import API payload 全文は保存しません。

search index rebuild 履歴を後続で扱う場合は、site build artifact の成功可否とは別に、検索 index の再生成単位、対象件数、source commit / manifest 参照、error summary を追う evidence として読みます。site build と同じ `GeneratedFileRun` に載せるか、別の read-only evidence とするかは、起動 surface が決まってから比較します。

## 保存候補 metadata

後続で concrete 起動 surface が確認できた場合も、保存候補は次の allowlist に限定します。

- `status`: rebuild の状態
- `started_at` / `finished_at`: rebuild 実行または観測時刻
- `source_repo` / `source_branch` / `source_commit_hash`: rebuild 入力の出自
- `manifest_path`: safe relative path の manifest 参照
- `manifest_document_count`: manifest 上の対象件数
- `indexed_document_count`: index 対象として処理した文書件数
- `indexed_record_count`: index entry の概算件数
- `error_summary`: 長い log 全文ではなく短い分類または先頭 summary

## 保存しない raw payload

次の値は、search index rebuild 履歴として保存しません。

- index payload 全文
- raw document body / markdown body / HTML body
- private path / absolute path
- credential-like value / token / secret-like env
- CI log 全文
- search index binary / JSONL 全文
- query log / user input log 全文
- external search provider response 全文

## replay / rebuild / human decision の分岐

search index rebuild 履歴を後続 issue に切る場合は、次のように分岐してから runtime 実装に進みます。

- `replay`: 既に保存済みの metadata だけで同じ rebuild 入力を安全に再観測できる場合に限る。index payload、document body、CI log 全文を保存して再投入する形にはしない。
- `rebuild`: source repo / branch / commit / manifest path などの allowlist metadata から、現在の rebuild entrypoint を再実行する形に閉じる。二重実行時の idempotency と重複 index 作成リスクを先に spec 化する。
- `human decision`: 起動 surface、保存先、`GeneratedFileRun` への統合可否、外部検索 provider response の扱い、scheduled rebuild / alert / SLA は人間判断が必要な proposal として残す。

この分岐は #4746 の proposal boundary であり、ここでは retry / replay UI、alert、scheduled rebuild policy を採用しません。

## 後続判断条件

次のいずれかが確認できるまで、runtime 実装は追加しません。

- search index rebuild を起動する concrete workflow、service、task、または controller action が決まっている
- rebuild の入力と出力が site build artifact evidence と分離して説明できる
- `GeneratedFileRun` に載せる場合の `job_id` / `generator` / `output_writer` / `event_source` が site build と衝突しない
- 別 evidence にする場合の一覧・詳細・検索入口が決まっている
- metadata allowlist と raw payload 非保存の representative spec / docs-quality guard が小さく切れている

## follow-up issue へ分ける条件

実装へ進む場合は、次の論点を 1 PR に混ぜず、別 issue に分けます。

- 履歴 model または `GeneratedFileRun` metadata へ載せるかの schema 判断
- rebuild 起動 service / task / controller action の追加
- request spec / job spec / docs-quality guard の追加
- replay / rebuild UI、手動再実行、scheduled rebuild、alert / notification / SLA policy の採用判断
- 外部 search provider response を扱う場合の保存境界と masking policy

## 非目標

- search index rebuild 実装そのもの
- Docusaurus site build / import build handoff 履歴の同時変更
- index payload、文書本文、private path、credential-like value、CI log 全文の保存
- 自動 retry / replay / alert / scheduled rebuild
- artifact 長期保存 policy の最終判断

## 確認観点

- `docs-site` artifact 履歴と search index rebuild 履歴を混ぜない
- 起動 surface 未確定のまま `GeneratedFileRun` への保存実装を追加しない
- 保存候補 metadata は allowlist として読み、raw payload 保存へ広げない
- 後続で concrete issue に切る場合は、起動 surface、保存 metadata、非保存 payload、spec / guard 範囲を 1 surface に閉じる
