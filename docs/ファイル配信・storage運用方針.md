# ファイル配信・storage運用方針

この文書は issue `#142` に対応する、`docs-portal` のファイル配信と storage 周辺の現行方針です。

## 1. 取り扱うファイル種別

本アプリは次を扱います。

- Docusaurus HTML
- JS / CSS / image asset
- Markdown 生ファイル
- PDF
- text / csv / json / yaml
- ZIP
- 画像

## 2. 保存先の役割

現行の責務分担:

- `storage/document_files/`: 添付・元ファイル
- `storage/docs_sites/`: Docusaurus build 成果物
- `storage/imports/`: import artifact staging

## 3. ローカル storage と GCS の差分

### ローカル storage

- `Rails.root/storage/...` を直接参照する
- `send_file` で配信する
- file existence を同期的に確認できる

### GCS 等のオブジェクトストレージ

- bucket / prefix 設計が必要
- object existence は API 越しに確認する
- signed URL かアプリ経由配信かを選ぶ必要がある

当面の方針:

- path / prefix 設計はローカル path 構造を踏襲する
- public access は禁止する
- 配信可否の判定はアプリ側に残す

## 4. MIME type / charset 方針

`DocumentFile#effective_content_type` は、拡張子ベースで次を補正します。

- `.md` / `.markdown`: `text/markdown`
- `.txt`: `text/plain`
- `.csv`: `text/csv`
- `.json`: `application/json`
- `.yml` / `.yaml`: `text/yaml`
- `.html`: `text/html`

`text/*` は `charset=utf-8` を付与します。

このため、現時点のルールは次です。

- Markdown / text / csv / yaml は UTF-8 charset 付き
- PDF は `application/pdf`
- JSON は `application/json`
- HTML asset は `text/html`
- JS / CSS asset は `Rack::Mime.mime_type` に従う

## 5. inline / attachment 方針

`DocumentFile` は次を inline 対象とします。

- PDF
- image/*
- text/*
- application/json

それ以外は attachment を基本にします。

`Content-Disposition` header は、ASCII fallback に加えて UTF-8 の `filename*` も付け、日本語ファイル名の download 互換性を確保します。

## 6. missing file 時の挙動

### 添付ファイル

`DocumentFilesController#show` は、解決済み path が存在しなければ `404 File not found` を返します。

### site build

Docusaurus site は `DocusaurusSiteRenderer` と `ProjectSitesController` / `DocumentSitesController` 側で path を検証し、対象 page が見つからなければ `RecordNotFound` として扱います。

### import

`DocumentImporter` は次を明示的に失敗させます。

- build directory not found
- attachment not found
- import root 外の path

## 7. path 安全性

現行コードでは次を防いでいます。

- `storage_key` の絶対 path
- `../` による path traversal
- `document_files` ルート外への脱出
- import root 外の artifact / manifest 参照

このため、GCS 移行時も「prefix 外参照を許さない」制約を維持します。

## 8. cleanup 方針

整理対象:

- import 一時展開物
- build 作業ディレクトリ
- 生成済み SVG
- 失敗 import artifact

現時点の方針:

- `storage/document_files` と `storage/docs_sites` は正本または復旧対象として扱う
- `storage/imports` は長期保管前提にしない
- cleanup の自動化は、誤削除防止のため retention 付きで設計する

## 9. storage 使用量の考え方

将来的な可視化対象:

- Project 単位の使用量
- Document 単位の使用量
- `document_files` / `docs_sites` / `imports` ごとの使用量

現時点では画面化されていないため、運用上はストレージメトリクスやバックアップサイズから把握します。

## 10. 監視との接続

監視対象として見るべきもの:

- missing file 件数
- storage 使用量
- GCS API 失敗
- import attachment copy 失敗
- site build 欠落

詳細は [監視・アラート設計](./監視・アラート設計.md) を参照します。

## 11. 現時点の運用ルール

- storage 配信判定はアプリ側に残す
- object storage 利用時も public access は許可しない
- missing file は 404 に統一し、原因は運用ログで追う
- MIME type / charset は `DocumentFile#effective_content_type` を正本として扱う
- cleanup 自動化は retention と restore 手順を先に決めてから導入する
