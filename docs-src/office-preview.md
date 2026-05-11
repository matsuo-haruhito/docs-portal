---
slug: /office-preview
---

# Office preview

Office preview は、文書に添付された `.doc`, `.docx`, `.xls`, `.xlsx`, `.ppt`, `.pptx` を embedded file viewer 内で表示する機能です。

## Preview provider の優先順位

1. Microsoft Graph preview
2. Google Drive viewer fallback

Microsoft Graph 接続が案件に設定されている場合は、従来通り Microsoft Graph を優先します。
Microsoft Graph 接続がない場合、または Graph の simple upload 制限を超える場合は、Google Drive 同期由来のファイルに限って Google Drive viewer に fallback します。

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

Microsoft Graph の simple upload 制限を超える Office file は Graph へアップロードしません。

## Google Drive viewer fallback

Google Drive fallback は、Google Drive 外部フォルダ同期で取り込まれたファイルだけが対象です。
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

## 権限上の注意

Google Drive viewer は、Rails サーバー側 OAuth token ではなく、利用者ブラウザ側の Google ログインセッションと Google Drive 側の権限で表示可否が決まります。

そのため、ポータル上では文書を閲覧できても、Google Drive 側で対象ファイルを閲覧できないユーザーには Google viewer 側でアクセス拒否が表示される場合があります。

## 表示フロー

```text
embedded file viewer
  ↓
GET /document_files/:public_id?embedded=1
  ↓
DocumentFileOfficePreview
  ↓
Microsoft Graph preview URL または Google Drive viewer URL へ redirect
```

Preview への遷移はファイル閲覧として access log に記録します。
Graph preview URL と Google Drive viewer URL は都度生成し、DB には永続化しません。

## Fallback できない場合

Microsoft Graph preview も Google Drive fallback も使えない場合、Office preview は不可として扱います。
通常のダウンロード導線は残します。

## 関連管理画面

- 連携メニュー: Microsoft Graph
- 連携メニュー: 外部フォルダ同期
- 連携メニュー: API仕様
