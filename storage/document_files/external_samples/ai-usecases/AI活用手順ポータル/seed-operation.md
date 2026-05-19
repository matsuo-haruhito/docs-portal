---
title: seed運用メモ
---

# seed運用メモ

このページは、AI活用手順ポータルをdocs-portalのseedデータとして扱うための運用メモです。

## 配置場所

AI活用手順ポータルのMarkdownとDSLは、以下に配置します。

```text
storage/document_files/external_samples/
└── ai-usecases/
    └── AI活用手順ポータル/
        ├── README.md
        ├── usecases.md
        ├── tools-and-capabilities.md
        ├── patterns.md
        ├── decision-flow.md                 # 生成物
        ├── data-model.md
        ├── seed-operation.md
        ├── data/
        │   └── decision_flow.yml            # 判断フローDSLの正本
        └── procedures/
            ├── PROC-CODE-GH-READ.md
            ├── PROC-CODE-LOCAL-READ.md
            ├── PROC-CODE-LOCAL-EDIT.md
            ├── PROC-CODE-GH-PR.md
            └── PROC-DOC-DRAFT.md

docs/ai-usecases/generated/
└── decision-flow.puml                       # decision_flow.yml から生成
```

## 取り込みの考え方

既存のseed処理は、`storage/document_files/external_samples` 配下のサンプル文書サイトを走査して、Project、Document、DocumentVersion、DocumentFile、DocumentPermissionを作成します。

このAI活用手順ポータルも、その既存ルールに合わせて配置しています。そのため、新しい専用Importerを追加せず、既存の external sample import の仕組みに乗せます。

## 想定されるProject

`external_samples/ai-usecases/AI活用手順ポータル` が1つのサンプル文書サイトとして扱われます。

| 項目 | 値 |
|---|---|
| sample-set | ai-usecases |
| site-dir | AI活用手順ポータル |
| Project名 | ai-usecases / AI活用手順ポータル |
| Document | 各Markdownファイルごとに作成 |
| DocumentVersion | current |
| visibility_policy | restricted_external |

## 判断フローの更新

判断フローは `decision-flow.md` を直接編集しません。正本は以下のYAMLです。

```text
storage/document_files/external_samples/ai-usecases/AI活用手順ポータル/data/decision_flow.yml
```

初期データ投入やローカル検証で明示的に再生成したい場合は、以下を実行します。

```bash
bin/rails ai_usecases:generate_flow
```

Rails環境を通さずに生成スクリプトだけ実行する場合は以下です。

```bash
ruby bin/generate_ai_usecase_flow
```

通常運用では、ファイル変更イベントから `GeneratedFileChangeEventJob` をenqueueし、該当する生成ジョブを非同期実行します。

生成されるファイルは以下です。

| 生成物 | 用途 |
|---|---|
| `storage/document_files/external_samples/ai-usecases/AI活用手順ポータル/decision-flow.md` | seedで取り込む判断フロー本文 |
| `docs/ai-usecases/generated/decision-flow.puml` | PlantUMLソースの単体ファイル |

## 自動生成ジョブ

元ファイル更新時に関連生成物を追従させるため、汎用の生成ジョブ基盤を用意しています。

| ファイル | 役割 |
|---|---|
| `config/file_change_event_jobs.yml` | ファイルCRUDイベントから起動するJobとパラメーターの定義 |
| `.github/generated-file-jobs.yml` | 生成JobID、生成コマンド、生成物のレジストリ |
| `.github/workflows/generated-file-jobs.yml` | push時に変更ファイルを検知して該当ジョブを実行するGitHub Actions |
| `app/services/generated_files/change_event_handler.rb` | ファイル変更イベントを受け取り、`config/file_change_event_jobs.yml` に従ってJobをenqueueする共通ハンドラ |
| `app/jobs/generated_file_change_event_job.rb` | 外部同期、手修正、アップロードなどから呼ぶファイル変更イベント用ActiveJob |
| `app/services/generated_files/runner.rb` | `.github/generated-file-jobs.yml` を読み、生成コマンドを実行する共通サービス |
| `app/jobs/generated_file_job.rb` | 実際の生成処理を実行するActiveJob |
| `bin/run_generated_file_jobs` | GitHub ActionsやローカルCLIから共通サービスを呼び出すrunner |

## ファイルCRUDイベントからの起動

通常運用では、Rakeを直接使うのではなく、何らかの方法でファイル変更が確定したタイミングで以下を呼びます。

```ruby
GeneratedFileChangeEventJob.perform_later(
  file_events: [
    { path: "storage/document_files/external_samples/ai-usecases/AI活用手順ポータル/data/decision_flow.yml", operation: "update" }
  ],
  event_source: "manual_edit",
  metadata: { actor_id: current_user.id }
)
```

後方互換として、単純な更新イベントなら以下も使えます。

```ruby
GeneratedFileChangeEventJob.perform_later(
  changed_files: ["storage/document_files/external_samples/ai-usecases/AI活用手順ポータル/data/decision_flow.yml"],
  event_source: "manual_edit",
  metadata: { actor_id: current_user.id }
)
```

`GeneratedFiles::ChangeEventHandler` は `config/file_change_event_jobs.yml` を参照し、CRUD種別、パスパターン、起動Job、渡すパラメーターを解決します。

定義例です。

```yaml
rules:
  - id: ai_usecase_decision_flow_generated_file_job
    operations:
      - create
      - update
      - delete
    path_patterns:
      - storage/document_files/external_samples/ai-usecases/AI活用手順ポータル/data/decision_flow.yml
    job_class: GeneratedFileJob
    params:
      changed_files: $matched_files
      job_ids:
        - ai_usecase_decision_flow
      event_source: $event_source
      metadata: $metadata
```

利用できるテンプレート値です。

| テンプレート | 内容 |
|---|---|
| `$changed_files` | イベント内の全変更ファイル |
| `$matched_files` | そのruleに一致したファイル |
| `$event_source` | 呼び出し元種別 |
| `$metadata` | 呼び出し元から渡されたメタデータ |
| `$operations` | 一致したCRUD種別 |

現在は、外部ファイル同期の apply 後に、同期で作成・更新・削除検知されたパスを収集して `GeneratedFileChangeEventJob` をenqueueします。今後、ドキュメント手修正、ファイルアップロード、管理画面の保存処理などでも同じJobを呼び出します。

処理の流れは以下です。

```text
外部ファイル同期 / 手修正 / アップロード
  ↓
GeneratedFileChangeEventJob
  ↓
GeneratedFiles::ChangeEventHandler
  ↓
config/file_change_event_jobs.yml でCRUDイベントに対応するJobを判定
  ↓
GeneratedFileJob など任意のJob
  ↓
GeneratedFiles::Runner
  ↓
.github/generated-file-jobs.yml の生成コマンド実行
  ↓
関連ファイル更新
```

## GitHub Actionsとの関係

GitHub Actionsは、リポジトリへのpushでDSLや生成スクリプトが変更された場合の安全網です。

`decision_flow.yml`、生成スクリプト、またはレジストリを更新してmainにpushすると、GitHub Actionsが該当ジョブを実行し、生成物に差分があれば `chore: update generated files` でmainへ自動コミットします。

アプリ内の `GeneratedFileJob` は作業ツリー上の生成物を更新する責務を持ち、GitHubへのコミット・pushはGitHub Actions側の責務として分けます。

## 手動実行

初期データ投入や検証用途では、以下のRake入口を使えます。

```bash
CHANGED_FILES=storage/document_files/external_samples/ai-usecases/AI活用手順ポータル/data/decision_flow.yml bin/rails generated_files:enqueue
```

特定ジョブIDを指定して投入する場合は以下です。

```bash
JOB_ID=ai_usecase_decision_flow bin/rails generated_files:enqueue_job
```

即時実行したい場合は `enqueue` の代わりに `run` / `run_job` を使います。

ローカルで汎用runnerを試す場合は、変更ファイルを引数で渡せます。

```bash
ruby bin/run_generated_file_jobs storage/document_files/external_samples/ai-usecases/AI活用手順ポータル/data/decision_flow.yml
```

## DSLの構造

`decision_flow.yml` は、以下の構造を持ちます。

| セクション | 役割 |
|---|---|
| `flow` | フロー全体のタイトル、説明、開始ラベル、図コードブロック言語 |
| `questions` | Yes/Noで分岐する判断ノード |
| `results` | 最終的に案内する手順ID、タイトル、ツール、リンク |
| `rule_table` | Markdownに表示するルール表 |

`questions` の `yes` / `no` は、別の質問ノードIDまたは `results` のIDを指します。

## seed実行

通常のseed実行で取り込まれます。

```bash
rails db:seed
```

Docker Compose環境では、既存の開発手順に合わせて実行します。

```bash
docker compose run --rm app bin/rails db:seed
```

## PlantUMLを図として表示したい場合

`decision-flow.md` にはPlantUMLのソースをデフォルトで `text` コードブロックとして置きます。これはKroki未設定環境でseedやbuildが失敗しないようにするためです。

PlantUMLを実際に図としてレンダリングしたい場合は、Kroki endpointを設定したうえで、以下の環境変数を付けて再生成します。

```bash
AI_USECASE_FLOW_DIAGRAM_LANGUAGE=plantuml bin/rails ai_usecases:generate_flow
```

Kroki設定例です。

```text
KROKI_ENDPOINT=http://kroki:8000
```

## 他機能へ応用する方法

別のDSLやCSVから生成物を作る場合は、`.github/generated-file-jobs.yml` に生成コマンドを追加し、`config/file_change_event_jobs.yml` にCRUDイベントから起動するJob定義を追加します。

```yaml
# .github/generated-file-jobs.yml
jobs:
  - id: sample_generator
    source_paths:
      - path/to/source.yml
    command: ruby bin/generate_sample
    generated_paths:
      - path/to/generated.md
      - path/to/generated.puml
```

```yaml
# config/file_change_event_jobs.yml
rules:
  - id: run_sample_generator
    operations:
      - create
      - update
    path_patterns:
      - path/to/source.yml
    job_class: GeneratedFileJob
    params:
      changed_files: $matched_files
      job_ids:
        - sample_generator
      metadata: $metadata
```

これにより、外部同期、手修正、ファイルアップロードなどの変更確定ハンドラから `GeneratedFileChangeEventJob` を呼ぶだけで、個別の生成処理を知らずに必要なJobを起動できます。

## 今後の拡張

| やりたいこと | 追加・変更箇所 |
|---|---|
| 新しいAIツールを追加する | tools-and-capabilities.md、将来的には tools.yml |
| 新しい能力を追加する | tools-and-capabilities.md、将来的には capabilities.yml |
| 新しいユースケースを追加する | usecases.md |
| 新しい利用パターンを追加する | patterns.md |
| 新しい手順書を追加する | procedures/ 配下にMarkdownを追加 |
| 判断フローを更新する | data/decision_flow.yml を変更する。ファイルCRUDイベントからGeneratedFileChangeEventJobが生成物更新をenqueueする |
| 管理画面やWebhookから生成を起動する | `GeneratedFileChangeEventJob.perform_later` を呼び出す |
| マスタ駆動生成に寄せる | data-model.md のYAML構造を正本化する |

## 現時点で自動生成する範囲

現時点では、手順書本文の自動生成までは行いません。自動生成するのは以下です。

- 判断フローMarkdown
- PlantUMLソース
- 判断ノード表
- 推奨手順一覧
- ルール表

手順書本文は、内容の品質とレビューしやすさを優先してMarkdownを直接管理します。

## 注意点

- `decision-flow.md` は生成物です。直接編集せず、`data/decision_flow.yml` を編集します。
- 自動生成コミットの再帰実行を避けるため、GitHub Actionsは `chore: update generated files` のコミットでは実行しません。
- Rails Jobはリポジトリ上の作業ツリー内ファイルを更新します。GitHubへのコミット・pushはGitHub Actions側の責務です。
- 手順書本文にツール名を直接埋め込みすぎると、ツール追加時の修正範囲が広がります。
- 手順書の正本をYAMLに寄せる場合は、Markdownは生成物として扱います。
- Kroki未設定環境では `plantuml` / `d2` コードブロックがbuild失敗要因になるため、図化前のソースは `text` として置きます。
