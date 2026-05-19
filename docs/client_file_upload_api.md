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
  -F "content_hash=sha256..." \
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
| `content_hash` | 任意 | 同期クライアント向けの内容ハッシュ。指定時はアップロード実体のSHA-256と照合する |
| `source_commit_hash` | 任意 | artifact import と揃えるための採用ハッシュ名。`content_hash` と両方ある場合、採用値はこちらを優先する |
| `version_label` | 任意 | 未指定時は `file-YYYYMMDDHHMMSS-<hash8>` |
| `status` | 任意 | 未指定時は `published` |

## 2. dry-run 結果確認

レスポンスには `dry_run_id` と `file_upload_preview` が含まれる。

```json
{
  "dry_run_id": "idry_xxxxx",
  "status": "analyzed",
  "file_upload_preview": {
    "source_name": "customer-local-sync",
    "relative_path": "docs/README.md",
    "source_path": "C:/work/customer-docs/docs/README.md",
    "file_size": 1234,
    "content_hash": "sha256...",
    "source_commit_hash": "sha256...",
    "version_label": "file-YYYYMMDDHHMMSS-hash8",
    "zip_import_preview": {
      "orphan_files": [],
      "skipped_files": [],
      "warnings": []
    }
  }
}
```

`source_path` は監査・表示用であり、manifest の branch metadata には使わない。
サーバー側の取り込み識別には `relative_path` と、採用後の `source_commit_hash` を使う。
クライアントは通常 `content_hash` を送ればよい。`content_hash` は `sha256:<hash>` 形式でも `<hash>` 形式でもよい。
`content_hash` が送られた場合は、`source_commit_hash` の有無に関わらずアップロード実体と照合する。不一致なら dry-run を作らない。
`source_commit_hash` と `content_hash` の両方があり、`content_hash` が実体と一致する場合は、採用値として `source_commit_hash` を優先する。
`version_label` を明示しない場合は、秒単位の時刻と内容ハッシュ先頭8桁から作る。

## 3. 本実行

```bash
curl -X POST "https://portal.example.com/api/internal/file_uploads" \
  -H "Authorization: Bearer ${DOC_IMPORT_TOKEN}" \
  -F "import_dry_run_id=idry_xxxxx"
```

成功時は `PublishJob` のIDと状態を返す。本実行レスポンスは公開反映結果だけを返し、dry-run 用の `file_upload_preview` は返さない。

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
