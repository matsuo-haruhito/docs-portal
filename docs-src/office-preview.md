---
slug: /office-preview
---

# Office preview

Office preview は、文書に添付された `.doc`, `.docx`, `.xls`, `.xlsx`, `.ppt`, `.pptx` を embedded file viewer 内で表示する機能です。

## Preview provider の優先順位

1. Microsoft Graph preview
2. Google Drive viewer fallback
3. Google Drive upload preview fallback

Microsoft Graph 接続が案件に設定されている場合は、Microsoft Graph を優先します。
Microsoft Graph 接続がない場合、Graph preview が失敗した場合、または Graph の simple upload 制限を超える場合は、Google Drive 側の preview を fallback として使います。

## Microsoft Graph preview

Microsoft Graph preview は、管理画面の **Microsoft Graph** で案件ごとに接続を設定します。
Rails は Office file を preview 用 Drive に一時アップロードし、アップロードした driveItem の `/preview` を呼び出します。

必要な主な設定値:

| 項目 | 内容 |
| --- | --- |
| Tenant ID | Microsoft Entra tenant ID |
| Client ID | アプリケーション client ID |
| Client secret | アプリケーション client secret。暗号化保存 |
| Drive ID | preview 用 Drive ID |
| プレビュー用フォルダ | preview 用 Drive 内の相対 path |

同じ `DocumentFile`、同じ Microsoft Graph 接続、同じファイル内容 fingerprint の場合、期限内の upload 済み driveItem を再利用します。
再表示時は再 upload せず、既存 driveItem に対して `/preview` を再発行します。

## Google Drive viewer fallback

Google Drive fallback は、Google Drive 外部フォルダ同期で取り込まれたファイルが対象です。
`ExternalFolderSyncItem#external_item_id` を Google Drive file ID として使い、viewer URL を生成します。

通常の Office / PDF などは次の形式です。

```text
https://drive.google.com/file/d/{FILE_ID}/preview
```

Google native file 由来の場合は、元の MIME type に応じて Google Docs / Sheets / Slides の preview URL を使います。

| 元ファイル | Preview URL |
| --- | --- |
| Google Docs | `https://docs.google.com/document/d/{FILE_ID}/preview` |
| Google Sheets | `https://docs.google.com/spreadsheets/d/{FILE_ID}/preview` |
| Google Slides | `https://docs.google.com/presentation/d/{FILE_ID}/preview` |
| Google Drawings | `https://docs.google.com/drawings/d/{FILE_ID}/preview` |

同期時に Google Docs / Sheets / Slides は `.docx` / `.xlsx` / `.pptx` として保存されますが、fallback preview では `provider_metadata.source_mime_type` を参照して元の Google native file の preview URL を生成します。

## Google Drive upload preview fallback

Google Drive 同期由来ではない portal 内ファイルや seed ファイルでも、Google Drive preview 用フォルダへ一時アップロードして Google viewer で表示できます。

必要な設定:

| 項目 | 内容 |
| --- | --- |
| `GOOGLE_DRIVE_PREVIEW_FOLDER_ID` | preview 用ファイルを置く Google Drive folder ID |
| Google OAuth接続 | `drive.readonly` と `drive.file` scope で再同意済みの OAuth接続 |

同じ `DocumentFile`、同じファイル内容 fingerprint の場合、期限内の upload 済み Google Drive file を再利用します。

## Preview upload のライフサイクル

Microsoft Graph preview upload と Google Drive upload preview は、DB に upload 記録を保存します。

| Provider | 記録テーブル | TTL env | デフォルトTTL |
| --- | --- | --- | --- |
| Microsoft Graph | `document_file_microsoft_graph_preview_uploads` | `MICROSOFT_GRAPH_PREVIEW_UPLOAD_TTL_HOURS` | 7日 |
| Google Drive | `document_file_google_drive_preview_uploads` | `GOOGLE_DRIVE_PREVIEW_UPLOAD_TTL_HOURS` | 7日 |

期限切れ upload は、定期ジョブで provider 側のファイルを削除し、DB 側は `deleted_at` を設定します。

管理対象の定期ジョブ:

| job_key | 内容 | 初期間隔 |
| --- | --- | --- |
| `cleanup_google_drive_preview_uploads` | Google Drive preview upload の期限切れ削除 | 24時間 |
| `cleanup_microsoft_graph_preview_uploads` | Microsoft Graph preview upload の期限切れ削除 | 24時間 |

`RecurringJobDispatcherJob` が1分ごとに起動し、`recurring_job_schedules` の `next_run_at` または `run_requested_at` を見て対象 job を enqueue します。
未登録の定期ジョブ定義は dispatcher 起動時に自動登録されます。

## 権限上の注意

Google Drive viewer は、利用者ブラウザ側の Google ログインセッションと Google Drive 側の権限で表示可否が決まります。

そのため、ポータル上では文書を閲覧できても、Google Drive 側で対象ファイルを閲覧できないユーザーには Google viewer 側でアクセス拒否が表示される場合があります。

Google Drive upload preview fallback でアップロードした preview 用ファイルも Google Drive 側の権限に依存します。

## 表示フロー

```text
embedded file viewer
  ↓
GET /document_files/:public_id?embedded=1
  ↓
DocumentFileOfficePreview
  ↓
Microsoft Graph preview URL / Google Drive viewer URL / Google Drive upload preview URL へ redirect
```

Preview への遷移はファイル閲覧として access log を記録します。
Graph preview URL は一時URLとして扱い、Google Drive viewer URL は元ファイルIDまたは upload 済み preview file ID から生成します。

## Fallback できない場合

Microsoft Graph preview、Google Drive 同期由来 preview、Google Drive upload preview のいずれも使えない場合、Office preview は不可として扱います。
通常のダウンロード導線は残します。

## 関連管理画面

- 連携メニュー: Microsoft Graph
- 連携メニュー: 外部フォルダ同期
- 連携メニュー: API仕様
- 管理メニュー: 定期ジョブ
- 管理メニュー: モデルブラウザ
