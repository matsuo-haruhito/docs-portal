# 情報露出 smoke evidence 運用メモ

このメモは `bin/external_user_exposure_smoke --format markdown` と `bin/operational_metadata_exposure_smoke --format markdown` を、PR / release evidence として安全に並べるための first slice です。CI 必須化、security policy、masking policy、代表 request spec の再編はここでは決めません。

2026-06-30 時点の smoke digest は、`next checklist` と `failure handoff` を出力本文に含みます。このメモの template は、その digest 行を PR / release evidence へ写すときの最小形として扱います。

## 使い分け

| 変更種別 | 使う smoke | 見る checklist | 主な確認対象 |
| --- | --- | --- | --- |
| 社外ユーザーの文書閲覧、検索、ZIP / download、AI context export、外部送付履歴、文書ショートカット | `bin/external_user_exposure_smoke --format markdown` | [社外ユーザー向け情報露出点検チェックリスト](./社外ユーザー向け情報露出点検チェックリスト.md) | current user の閲覧権限外に文書本文、添付、検索候補、export payload が広がらないこと |
| admin / integration の raw path、provider metadata、Webhook / Graph / Git / generated file run preview | `bin/operational_metadata_exposure_smoke --format markdown` | [運用 metadata 情報露出点検チェックリスト](./運用metadata情報露出点検チェックリスト.md) | 調査に必要な bounded summary に閉じ、raw path、raw payload、token-like value、PII-like value、外部 ID、provider payload を貼らないこと |
| 両方に触れる PR / release | 両方を同じ evidence block に並べる | 両 checklist | 社外ユーザーの閲覧権限境界と admin / integration metadata 境界を混同しないこと |

## PR / release evidence template

2 つの digest を並べる場合は、次の最小項目だけを残します。digest 本文に出ない raw value を手で追記しません。

```markdown
### 情報露出 smoke evidence

- external user exposure: `bin/external_user_exposure_smoke --format markdown`
  - result: passed / failed
  - next checklist: `docs/社外ユーザー向け情報露出点検チェックリスト.md`
  - failure handoff: 対象 spec / surface / runbook へ戻って確認する。HTML / JSON / ZIP payload、raw response、token-like value、文書タイトル、添付 metadata、権限外文書名は貼らない。
- operational metadata exposure: `bin/operational_metadata_exposure_smoke --format markdown`
  - result: passed / failed
  - next checklist: `docs/運用metadata情報露出点検チェックリスト.md`
  - failure handoff: 対象 spec / surface / runbook へ戻って確認する。raw path、raw payload、token-like value、PII-like value、Webhook / Graph details、外部 ID、provider payload は貼らない。
```

`next checklist` と `failure handoff` は smoke digest 自体が出す行です。PR / release evidence ではこの 2 行を要約せず、失敗時の詳細 payload や raw value を足して補強しないでください。digest 表の `next runbook` は、上記の `runbook` 戻り先として扱います。

## 失敗時の戻り先

- smoke が失敗した場合は、Markdown digest の表にある `spec`、`surface`、`next runbook` と `next checklist` を起点に確認します。
- PR コメントや release note には、失敗した spec 名、対象 surface、次に見る checklist / runbook、再実行した command だけを残します。
- raw payload、raw response、document title、token、private-looking path、provider payload を evidence に転記しません。
- docs だけで安全化できない raw value 表示を見つけた場合は、このメモで判断せず別 issue または `needs-human` に戻します。

## 守る境界

- `external_user_exposure_smoke` は社外ユーザーの閲覧権限境界を確認する入口です。admin / integration metadata の raw 表示判断を混ぜません。
- `operational_metadata_exposure_smoke` は admin / integration metadata の表示境界を確認する入口です。社外ユーザーの文書閲覧許可や authorization policy を新しく決めません。
- どちらの Markdown digest も bounded summary であり、詳細調査用の raw evidence 置き場ではありません。
