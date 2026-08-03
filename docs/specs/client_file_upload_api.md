# Client file upload API flow

この文書は内部 API 名の設計経緯と位置づけを記述する。

API の詳細仕様（エンドポイント、パラメータ、リクエスト例、レスポンス例、hash の扱い、path validation）は [docs-src/client-file-upload-api.md](../../docs-src/client-file-upload-api.md) を参照。

## 位置づけ

同期クライアントや簡易アップローダーが単体ファイルを取り込むための API。
アップロードと公開は分離し、必ず dry-run を作ってから本実行する設計。

命名経緯や他の import API との使い分けは [internal_upload_api_naming.md](./internal_upload_api_naming.md) を参照。
