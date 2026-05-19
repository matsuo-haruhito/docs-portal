# Client file upload API flow

同期クライアントや簡易アップローダーは、単体ファイルを `POST /api/internal/file_uploads` に送る。
アップロードと公開は分離し、必ず dry-run を作ってから本実行する。

## 1. dry-run 作成

```bash
curl -X POST "https://portal.example.com/api/internal/file_uploads" \
  -H "Authorization: Bearer ${DOC_IMPORT_TOKEN}" \
  -F "project_code=my-project" \
  -F "file=@README.md" \
  -F "relative_path=docs/README.md" \
  -F "source_path=C:/work/customer-docs/docs/README.md" \
  -F "source_name=customer-local-sync" \
  -F "validate_only=true"
```

### 主なパラメータ

| parameter | required | note |
| --- | --- | --- |
| `project_code` | dry-run時必須 | 取り込み先案件コード |
| `file` | dry-run時必須 | multipart upload のファイル実体 |
| `relative_path` | 任意 | 同期元フォルダ内の相対パス。未指定時はアップロードファイル名 |
| `source_path` | 任意 | クライアントPC上のフルパスなどの参考情報。取り込み先決定には使わない |
| `source_name` | 任意 | 同期元名。未指定時は `file_upload` |
| `source_commit_hash` | 任意 | クライアントが算出した内容ハッシュ。未指定時はサーバーが元ファイルのSHA-256を使う |
| `version_label` | 任意 | 未指定時は `file-YYYYMMDDHHMMSS` |
| `status` | 任意 | 未指定時は `published` |

## 2. dry-run 結果確認

レスポンスには `dry_run_id` と `file_upload_preview` が含まれる。

```json
{
  "dry_run_id": "idry_xxxxx",
  "status": "analyzed",
  "file_upload_preview": {
    "relative_path": "docs/README.md",
    "source_path": "C:/work/customer-docs/docs/README.md",
    "file_size": 1234,
    "source_commit_hash": "sha256...",
    "zip_import_preview": {
      "orphan_files": [],
      "skipped_files": [],
      "warnings": []
    }
  }
}
```

`source_path` は監査・表示用であり、manifest の branch metadata には使わない。
サーバー側の取り込み識別には `relative_path` と `source_commit_hash` を使う。

## 3. 本実行

```bash
curl -X POST "https://portal.example.com/api/internal/file_uploads" \
  -H "Authorization: Bearer ${DOC_IMPORT_TOKEN}" \
  -F "import_dry_run_id=idry_xxxxx"
```

成功時は `PublishJob` のIDと状態を返す。

```json
{
  "publish_job_id": 123,
  "status": "imported",
  "import_dry_run_id": "idry_xxxxx"
}
```

## dry-run mode の注意

`file_uploads` で作った dry-run は `file_uploads` で本実行する。
`zip_uploads` で作った dry-run は `zip_uploads` で本実行する。
別APIの `import_dry_run_id` を渡しても実行しない。

## path validation

`relative_path` は次を拒否する。

- 空文字
- `/README.md` のような絶対パス
- `../README.md` や `docs/../README.md` のような traversal
- `C:/work/docs/README.md` のような Windows フルパス

`docs\\README.md` のような Windows 区切りの相対パスは `docs/README.md` に正規化する。
