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
| `content_hash` | ファイル実体の SHA-256 |
| `validate_only` | 任意。`true` でも dry-run 作成になるが、`file` があれば省略可 |

`relative_path` はサーバー側でも traversal / absolute path / Windows full path を拒否する。
通常の同期クライアントは `relative_path` を必ず送る。単体ファイル選択UIなど、同期ルート相対パスを持たないクライアントは upload file の `original_filename` に fallback できるが、unsafe な名前は拒否される。

`content_hash` はアップロード破損検知に使う。
サーバーは受信ファイルの SHA-256 と照合し、不一致なら dry-run を作らない。

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

## まず作る最小クライアント

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
