# Local folder sync client design

NAS やローカルフォルダを docs-portal に同期するための常駐クライアント案。

## 目的

- クライアントPCやNAS上のフォルダ変更を検知し、docs-portal へ単体ファイル upload dry-run を作る
- ポータル側では dry-run 結果を確認してから公開する
- 公開時に DocumentVersion / DocumentFile を更新する

## 基本フロー

1. 同期対象フォルダを設定する
2. ファイル変更を検知する
3. 対象ファイルの SHA-256 を計算する
4. `POST /api/internal/file_uploads` に `file` とメタデータを送って dry-run を作る
5. レスポンスの `file_upload_preview` と dry-run 結果を確認する
6. 公開してよい dry-run だけ `import_dry_run_id` で本実行する

`file_uploads` は `file` パラメータがあるリクエストを dry-run 作成として扱うため、同期クライアントは `validate_only=true` を省略できる。
本実行時は `file` を送らず、`import_dry_run_id` だけを送る。

## FileSystemWatcher 方針

.NET などで常駐クライアントを作る場合は `FileSystemWatcher` を使う。

監視イベントはそのまま即送信せず、短い debounce を入れる。

- `Created`
- `Changed`
- `Renamed`
- `Deleted`

初期スライスでは `Created` / `Changed` / `Renamed` を upload 対象にする。
`Deleted` は portal 側で即削除せず、後続で削除候補 dry-run として扱う。
現時点の `file_uploads` API はファイル追加・更新の入口であり、削除同期は扱わない。

## 送信パラメータ

| parameter | value |
| --- | --- |
| `project_code` | 同期先案件コード |
| `file` | multipart upload のファイル実体。指定された場合は dry-run 作成になる |
| `relative_path` | 同期ルートからの相対パス。省略時は upload file の `original_filename` を使う |
| `source_path` | クライアント上のフルパスやNASパス |
| `source_name` | 同期元名。例: `customer-nas-sync` |
| `content_hash` | ファイル実体の SHA-256。`sha256:` 接頭辞付き、または 64 桁 hex で送る |
| `validate_only` | 任意。`true` でも dry-run 作成になるが、`file` があれば省略可 |

`relative_path` はサーバー側でも traversal / absolute path / Windows full path を拒否する。
通常の同期クライアントは `relative_path` を必ず送る。単体ファイル選択UIなど、同期ルート相対パスを持たないクライアントは upload file の `original_filename` に fallback できるが、unsafe な名前は拒否される。

`content_hash` はアップロード破損検知に使う。
サーバーは受信ファイルの SHA-256 と照合し、不一致なら dry-run を作らない。
`sha256:` 接頭辞付きで送っても照合時には 64 桁 hex へ正規化される。

レスポンスの `file_upload_preview.content_hash` は、クライアントが送った値ではなく、サーバーが実際に受信したファイルから計算した SHA-256 として扱う。
クライアントは送信前に計算した SHA-256 とレスポンスの `file_upload_preview.content_hash` をログに残すと、再送や問い合わせ時に追跡しやすい。

## キューとリトライ

FileSystemWatcher のイベントは重複しやすいため、クライアント側で queue に積む。

推奨キー:

```text
source_name + relative_path + content_hash
```

同じキーのイベントはまとめる。
送信失敗時は指数バックオフで再試行する。

リトライ対象:

- ネットワークエラー
- 5xx
- タイムアウト

リトライしない対象:

- 401 / 403
- 404 project not found
- 400 relative_path invalid
- 400 content_hash mismatch

## ファイル安定待ち

変更検知直後は、ファイル書き込み中の可能性がある。
送信前に短時間の安定待ちを行う。

例:

- 1 秒待つ
- サイズと更新時刻を取得する
- さらに 1 秒待つ
- サイズと更新時刻が変わっていなければ送信する

## dry-run と公開

同期クライアントは原則として dry-run 作成までを行う。
公開判断は portal 側で行う。

将来、自動公開が必要になった場合も、次の条件を満たす場合だけに限定する。

- `content_hash` が一致している
- preview に error がない
- 対象 project / relative_path が自動公開許可リストに含まれる
- 同名更新や新規追加のルールが明確

## セキュリティ

- token はOSの資格情報ストアなどに保存する
- ログに token を出さない
- `source_path` は監査用であり、サーバー側の保存先決定には使わない
- `relative_path` はサーバー側でも traversal / absolute path / Windows full path を拒否する

## 最小 reference uploader

`bin/local_folder_sync_upload` は first slice の単発 reference client。
1 ファイルを読み、同期ルートからの `relative_path` と送信前 SHA-256 を作って `POST /api/internal/file_uploads` の dry-run を作る。
常駐監視、debounce queue、retry、削除同期、publish apply はまだ行わない。

推奨コマンドは `ruby bin/local_folder_sync_upload` とする。
checkout 環境で executable bit が付いている場合は `bin/local_folder_sync_upload` でも実行できるが、contents API 経由の追加や環境差で実行 bit が落ちる可能性があるため、PR / release evidence では `ruby` 経由の例を正本にする。

環境変数で実行する例:

```bash
DOCS_PORTAL_URL=https://portal.example.test \
DOC_IMPORT_TOKEN=... \
DOCS_PORTAL_PROJECT_CODE=PROJECT1 \
LOCAL_FOLDER_SYNC_ROOT=/path/to/sync-root \
LOCAL_FOLDER_SYNC_SOURCE_NAME=customer-nas-sync \
LOCAL_FOLDER_SYNC_FILE=/path/to/sync-root/docs/guide.md \
ruby bin/local_folder_sync_upload
```

同じ値は option でも渡せる。

```bash
ruby bin/local_folder_sync_upload \
  --portal-url=https://portal.example.test \
  --token=... \
  --project-code=PROJECT1 \
  --sync-root=/path/to/sync-root \
  --source-name=customer-nas-sync \
  --file=/path/to/sync-root/docs/guide.md
```

標準出力には `dry_run_id`、`status`、`relative_path`、送信前 hash、サーバー計算 hash、hash 一致結果だけを出す。
token と client 上の `source_path` は標準出力やエラーに出さない。
PR / release evidence には、この summary と dry-run only の境界だけを貼り、token、ローカル絶対パス、NAS の private path、raw response payload は貼らない。

PR / release evidence は次の粒度に留める。

```text
local_folder_sync_upload smoke
command: ruby bin/local_folder_sync_upload
status: created
relative_path: docs/guide.md
client_hash: sha256:<redacted>
server_hash: sha256:<redacted>
hash_match: true
dry_run_only: true
raw_token: not logged
raw_source_path: not logged
```

`client_hash` と `server_hash` は一致確認のための証跡として使う。社外共有や長期保存が不要な PR comment では、hash 全体ではなく先頭数桁だけに丸めてもよい。`dry_run_id` は portal 内部の確認に必要な場合だけ貼り、token、local absolute path、NAS path、raw response JSON は貼らない。

確認は次の 2 種類に分ける。

- unit / source smoke: sync root 外 path の拒否、unsafe `relative_path` の拒否、token / raw `source_path` を summary に出さないことを確認する。実 portal への upload は不要。
- staging / local portal manual smoke: 実 portal へ 1 ファイルを dry-run upload し、dry-run が作られること、hash が一致すること、summary が redacted であることだけを確認する。publish apply、削除同期、常駐監視、retry queue は同じ smoke に含めない。

client 側でも次の file path は送信前に拒否する。

- sync root 外の path
- absolute path を `relative_path` として扱う必要がある path
- `..` を含む traversal path
- 空の relative path

## まず作る常駐クライアント

reference uploader の後続として、常駐クライアントでは次を扱う。

- 設定ファイル
  - portal URL
  - token
  - project_code
  - sync root
  - source_name
- 起動時の全件 scan
- FileSystemWatcher による変更検知
- debounce queue
- SHA-256 計算
- `file_uploads` dry-run 作成
- 成功 / 失敗ログ
- 再試行キュー

公開実行、削除同期、GUI、サービス登録、複数project同期は後続で扱う。
