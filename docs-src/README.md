# docs-src/

公開 API 仕様の Markdown 正本ディレクトリ。
Docusaurus build の入力ファイルとして使用される。

## 運用ルール

- このディレクトリ内の `.md` ファイルが公開 API 仕様の **Single Source of Truth（正本）** である
- `docs/` 側には API 仕様の詳細（エンドポイント一覧・リクエスト/レスポンス例・手順）を本文として置かない
- `docs/` 側で参照する場合は「詳細は `docs-src/<ファイル名>` を参照」のポインタのみ記載する
- 新しい公開 API 仕様を追加する場合はこのディレクトリに `.md` ファイルを作成する

## ファイル一覧

| ファイル | 内容 |
|---------|------|
| `api-specification.md` | Internal import API と外部連携の管理者向け仕様 |
| `client-file-upload-api.md` | 単体ファイルアップロード API 仕様 |
| `external-folder-sync-webhooks.md` | 外部フォルダ同期 Webhook 受信仕様 |
| `office-preview.md` | Office ファイルの embedded preview 仕様 |
| `intro.md` | Docusaurus build 用トップページ（最小サンプル） |
