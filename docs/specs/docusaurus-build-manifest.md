# Docusaurus build manifest

Docusaurus build manifest は、生成済み HTML preview がどの profile / commit / entry path から作られたかを docs-portal が確認するための JSON metadata です。

## 目的

- viewer で表示している HTML が、文書版の source commit と対応しているか確認する
- build profile の取り違えを quality check で検出する
- entry path の不一致を検出する
- build が失敗した成果物や古い成果物を preview で見落とさないようにする

## manifest file names

Docusaurus build 出力には、次のいずれかの JSON file を置きます。

1. `.docs-portal-build-manifest.json`
2. `docs-portal-build-manifest.json`
3. `build-manifest.json`

探索順は、まず `DocumentVersion#site_build_path` の出力 directory、次に version の site root directory です。

例:

```text
storage/docs_sites/<document_version_id>/docs/manual/.docs-portal-build-manifest.json
storage/docs_sites/<document_version_id>/.docs-portal-build-manifest.json
```

## schema

```json
{
  "profile": "production",
  "source_commit": "abc123",
  "built_at": "2026-05-20T00:00:00Z",
  "entry_path": "docs/manual",
  "build_result": "success"
}
```

| key | 必須度 | 意味 |
| --- | --- | --- |
| `profile` | 推奨 | build profile。例: `test`, `production` |
| `source_commit` | 推奨 | build 元の source commit hash |
| `built_at` | 推奨 | build 完了時刻。ISO 8601 文字列 |
| `entry_path` | 推奨 | preview entry path |
| `build_result` | 推奨 | `success` の場合のみ成功扱い |

## quality check warnings

`DocumentVersion#site_build_path` が空の場合、manifest check は行いません。

| code | 条件 |
| --- | --- |
| `manifest_missing` | `site_build_path` があるが manifest file が見つからない |
| `invalid_json` | manifest が JSON として parse できない |
| `profile_mismatch` | manifest の `profile` が expected profile と一致しない |
| `source_commit_mismatch` | manifest の `source_commit` が文書版の `source_commit_hash` と一致しない |
| `entry_path_mismatch` | manifest の `entry_path` が文書版の preview entry path と一致しない |
| `build_result_failed` | manifest の `build_result` が `success` ではない |
| `stale_build` | `built_at` が stale threshold より古い |

現時点の stale threshold は 7 日です。

## version page display

文書版詳細の「プレビュー状態」カードには、`site_build_path` が設定されている場合に次を表示します。

- `Build manifest`: 読み取った manifest source path。未検出の場合は `未検出`
- `Manifest warning`: warning 件数
- warning がある場合は `Docusaurus build manifest warnings` details に code / message / detail を表示

## current non-goals

- Docusaurus build を docs-portal 側で直接実行すること
- manifest の schema validation を厳格化して build を止めること
- manifest によって公開可否や権限を変更すること
- path history / redirect を manifest で扱うこと
