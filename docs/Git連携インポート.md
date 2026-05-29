# Git連携インポート

この文書は issue `#120` に対応する、Gitリポジトリ連携インポートの初期実装範囲を記録する。

管理画面での登録手順、手動同期、同期履歴の見返し方は [Git連携設定と同期失敗確認 runbook](./Git連携設定と同期失敗確認runbook.md) を参照してください。このページは current implementation が何を取り込むかの正本に留めます。

## 目的

- GitHub 等の Git リポジトリから指定ブランチ・指定パス配下の Markdown と添付を取り込む
- push 型の internal import API と pull 型の Git 同期で、DocumentImporter を共通利用する
- 取り込み元 repository / branch / source_path / commit SHA を追跡する
- Git 側で削除されたファイルは即 delete せず、同期結果の削除候補として記録する

## 外部同期の基準契約

Git 連携は、後続の Google Drive / SharePoint 同期が参照するための基準実装として次の境界を持つ。

### 外部同期共通概念

- 同期元設定: 取り込み先 Project、provider、認証方式、有効/無効を保持する
- run 履歴: provider、import mode、status、開始/終了時刻、失敗理由を run 単位で保持する
- manifest 化: provider 固有の入力を DocumentImporter 用 manifest に変換し、Document / DocumentVersion / DocumentFile 作成は DocumentImporter に委ねる
- summary_json: imported / skipped / failed の判断材料、取り込み件数、添付件数、削除候補、PublishJob ID を記録する
- 削除候補: 外部側で消えたものを即 delete せず、確認用の候補として run に残す

### Git 専用概念

- `repository_full_name`: `owner/repo` 形式の GitHub repository
- `branch`: 取り込み対象 branch
- `source_path`: 取り込み対象ディレクトリ。初期値は `docs`
- `commit_sha`: run が参照した Git revision
- `last_synced_commit_sha`: 同じ commit の再取り込みを `skipped` にするための Git 専用 checkpoint

Google Drive / SharePoint では folder ID、drive ID、delta token など別の revision / location 情報を使う想定であり、Git 専用の repository / branch / commit SHA を共通 API として押し広げない。

## モデル

### GitImportSource

pull 型同期の設定。

- `project_id`: 取り込み先 Project
- `provider`: 初期実装では `github`
- `repository_full_name`: `owner/repo`
- `branch`: 取り込み対象ブランチ
- `source_path`: 取り込み対象ディレクトリ。初期値は `docs`
- `auth_type`: `github_app` / `fine_grained_pat` / `deploy_key` / `no_auth`
- `installation_id`: GitHub App installation を使う場合の識別子
- `credential_ref`: secret store 等を使う場合の参照名
- `credential_secret`: 検証用 fine-grained PAT。Active Record Encryption で暗号化保存する
- `last_synced_commit_sha`, `last_synced_at`: 最終同期状態

GitHub App を本命とし、fine-grained PAT は開発・検証用、`no_auth` は公開 repository 用として扱う。current implementation では fine-grained PAT のみ credential secret を必須にしている。GitHub App installation token 発行、repository 一覧取得、branch / path picker は未実装の境界に置く。

### GitImportRun

pull / push の同期履歴。

- `import_mode`: `pull` / `push`
- `provider`, `repository_full_name`, `branch`, `source_path`, `commit_sha`
- `status`: `pending` / `running` / `imported` / `skipped` / `failed`
- `summary_json`: 取り込み件数、添付件数、削除候補、PublishJob ID など
- `error_message`: 失敗理由

`imported` は DocumentImporter まで到達して新しい取り込みを作った状態、`skipped` は同一 commit や対象文書なしで新しい DocumentVersion を作らなかった状態、`failed` は fetch / manifest build / import のどこかで例外または validation error により止まった状態を表す。

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

- Google Drive / SharePoint / OneDrive 同期本体
- GitHub App installation token の発行と repository 一覧取得の完全実装
- branch / path picker
- deploy key による clone
- Webhook 自動同期
- 定期同期
- Git 側削除の自動 archive / delete
