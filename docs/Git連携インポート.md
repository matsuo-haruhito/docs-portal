# Git連携インポート

この文書は issue `#120` に対応する、Gitリポジトリ連携インポートの初期実装範囲を記録する。

管理画面での登録手順、手動同期、同期履歴の見返し方は [Git連携設定と同期失敗確認 runbook](./Git連携設定と同期失敗確認runbook.md) を参照してください。このページは current implementation が何を取り込むかの正本に留めます。

## 目的

- GitHub 等の Git リポジトリから指定ブランチ・指定パス配下の Markdown と添付を取り込む
- push 型の internal import API と pull 型の Git 同期で、DocumentImporter を共通利用する
- 取り込み元 repository / branch / source_path / commit SHA を追跡する
- Git 側で削除されたファイルは即 delete せず、同期結果の削除候補として記録する

## モデル

### GitImportSource

pull 型同期の設定。

- `project_id`: 取り込み先 Project
- `provider`: 初期実装では `github`
- `repository_full_name`: `owner/repo`
- `branch`: 取り込み対象ブランチ
- `source_path`: 取り込み対象ディレクトリ。初期値は `docs`
- `auth_type`: `github_app` / `fine_grained_pat` / `deploy_key` / `none`
- `installation_id`: GitHub App installation を使う場合の識別子
- `credential_ref`: secret store 等を使う場合の参照名
- `credential_secret`: 検証用 fine-grained PAT。Active Record Encryption で暗号化保存する
- `last_synced_commit_sha`, `last_synced_at`: 最終同期状態

GitHub App を本命とし、fine-grained PAT は開発・検証用の暫定手段として扱う。

### GitImportRun

pull / push の同期履歴。

- `import_mode`: `pull` / `push`
- `provider`, `repository_full_name`, `branch`, `source_path`, `commit_sha`
- `status`: `pending` / `running` / `imported` / `skipped` / `failed`
- `summary_json`: 取り込み件数、添付件数、削除候補、PublishJob ID など
- `error_message`: 失敗理由

## pull 型の流れ

1. 管理画面で GitImportSource を登録する
2. 管理者が手動同期を実行する
3. GitRepositorySnapshotFetcher が対象 repository / branch を一時ディレクトリへ clone する
4. GitImportManifestBuilder が `source_path` 配下の Markdown と添付を DocumentImporter 用 manifest に変換する
5. DocumentImporter が既存の import pipeline で Document / DocumentVersion / DocumentFile を作成する
6. GitImportRun に結果を保存し、GitImportSource の最終同期 commit SHA を更新する

同じ commit SHA が既に同期済みの場合は `skipped` として記録し、新しい DocumentVersion は作らない。

## 取り込み対象

- `*.md`, `*.mdx` を Document として扱う
- 同階層の添付ファイルを DocumentFile として扱う
- Mermaid / PlantUML / D2 専用ファイルは添付として保持する
- `source_path` 外のファイルは取り込まない

Markdown 本体も DocumentFile として保存し、後から取り込み元の原文を確認できるようにする。

## 削除ファイルの扱い

Git 側で消えたファイルは即座に Document を削除しない。同期結果の `summary_json.deleted_candidates` に既存 DocumentVersion の source path を記録し、archive / delete の判断は危険操作の方針に従って別操作で行う。

## push 型との関係

既存の internal import API は `DocumentImporter` を利用しており、dry-run では `import_mode: git_push` を記録する。pull 型も最終的には同じ manifest 形式に変換して `DocumentImporter` へ渡すため、Document / DocumentVersion / DocumentFile の作成責務は二重化しない。

## 初期実装で未対応のこと

- GitHub App installation token の発行と repository 一覧取得の完全実装
- deploy key による clone
- Webhook 自動同期
- 定期同期
- Git 側削除の自動 archive / delete
