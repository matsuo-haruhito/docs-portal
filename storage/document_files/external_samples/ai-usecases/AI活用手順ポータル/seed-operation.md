---
title: seed運用メモ
---

# seed運用メモ

このページは、AI活用手順ポータルをdocs-portalのseedデータとして扱うための運用メモです。

## 基本方針

- GitHub上の正本はGitHub側で管理します。
- docs-portal上の正本はdocs-portal側で管理します。
- GitHubとdocs-portalの同期は双方向ではありません。
- 同期や生成に失敗した場合、再実行されるまで正本がずれることは許容します。
- docs-portalは当面GitHubへ書き込みません。

## 配置場所

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

## seedでの取り込み

既存のseed処理は、`storage/document_files/external_samples` 配下のサンプル文書サイトを走査して、Project、Document、DocumentVersion、DocumentFile、DocumentPermissionを作成します。

このAI活用手順ポータルも、その既存ルールに合わせて配置しています。

```bash
rails db:seed
```

Docker Compose環境では以下です。

```bash
docker compose run --rm app bin/rails db:seed
```

## 判断フローの更新

`decision-flow.md` は生成物です。直接編集せず、以下を正本として編集します。

```text
storage/document_files/external_samples/ai-usecases/AI活用手順ポータル/data/decision_flow.yml
```

初期データ投入やローカル検証で明示的に再生成したい場合は、以下を実行します。

```bash
bin/rails ai_usecases:generate_flow
ruby bin/generate_ai_usecase_flow
```

通常運用では、ファイルCRUDイベントから `GeneratedFileChangeEventJob` をenqueueし、該当する生成ジョブを非同期実行します。

## 自動生成ジョブの設定ファイル

| ファイル | 役割 |
|---|---|
| `config/file_change_event_jobs.yml` | ファイルCRUDイベントから起動するJobとパラメーターの定義 |
| `config/generated_file_jobs.yml` | GeneratedFileJobが実行する生成JobID、generator、output writer、生成物の定義 |
| `.github/workflows/generated-file-jobs.yml` | GitHub push時に `config/generated_file_jobs.yml` を読んで生成物を更新する安全網 |
| `app/services/generated_files/change_event_handler.rb` | CRUDイベントを受け取り、`config/file_change_event_jobs.yml` に従ってJobをenqueueする共通ハンドラ |
| `app/jobs/generated_file_change_event_job.rb` | 外部同期、手修正、アップロードなどから呼ぶファイル変更イベント用ActiveJob |
| `app/services/generated_files/runner.rb` | `config/generated_file_jobs.yml` を読み、generatorまたは後方互換のcommandを実行する共通サービス |
| `app/services/generated_files/run_recorder.rb` | 生成実行履歴を `generated_file_runs` に記録するrecorder |
| `app/models/generated_file_run.rb` | 生成実行履歴モデル |
| `app/services/generated_files/artifact.rb` | Generatorが返す生成成果物の値オブジェクト |
| `app/services/generated_files/output_writers/filesystem.rb` | 生成成果物をファイルシステムへ保存するOutputWriter |
| `app/services/generated_files/output_writers/document_version.rb` | 生成成果物をDocumentVersion / DocumentFile / storageへ保存するOutputWriter |
| `app/services/generated_files/generators/ai_usecase_decision_flow.rb` | AI活用判断フローDSLをMarkdown/PlantUMLへ変換するGenerator class |
| `app/jobs/generated_file_job.rb` | 実際の生成処理を実行するActiveJob |
| `bin/run_generated_file_jobs` | GitHub ActionsやローカルCLIから共通サービスを呼び出すrunner |

## ファイルCRUDイベントからの起動

通常運用では、Rakeを直接使うのではなく、ファイル変更が確定したタイミングで以下を呼びます。

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

## 生成Job定義

`GeneratedFileJob` が実行する生成処理は `config/generated_file_jobs.yml` に定義します。

```yaml
jobs:
  - id: ai_usecase_decision_flow
    source_paths:
      - storage/document_files/external_samples/ai-usecases/AI活用手順ポータル/data/decision_flow.yml
    generator: ai_usecase_decision_flow
    output_writer: filesystem
    generated_paths:
      - storage/document_files/external_samples/ai-usecases/AI活用手順ポータル/decision-flow.md
      - docs/ai-usecases/generated/decision-flow.puml
```

`generator` は `GeneratedFiles::Runner::GENERATORS` のAllowListに登録されたGenerator classへ解決されます。Generatorは `GeneratedFiles::Artifact` を返し、`output_writer` が保存先を決めます。既存互換として `command` も実行できますが、新規追加はGenerator class方式を優先します。

## OutputWriter

現時点では `filesystem` と `document_version` に対応しています。

```text
GeneratedFiles::Generators::*
  ↓ Artifact[]
GeneratedFiles::OutputWriters::*
  ↓ 保存先へ保存
```

`filesystem` は生成成果物を作業ツリー上のファイルへ保存します。

```yaml
output_writer: filesystem
```

`document_version` は生成成果物を1つのDocumentVersionとして保存し、各ArtifactをDocumentFileとして添付します。

```yaml
output_writer: document_version
output_options:
  project_code: sample-project
  document_slug: ai-usecase-generated-flow
  document_title: AI活用判断フロー生成結果
  document_category: other
  document_kind: mixed
  visibility_policy: internal_only
  importance_level: reference
  version_label_prefix: generated-flow
  source_identifier: generated:ai_usecase_decision_flow
```

`document_version` writer はdocs-portal側を正本にするための足場です。既存のAI活用判断フローは、GitHub側のseedサンプルとの互換を維持するため、まだ `filesystem` のままです。

## 生成実行履歴

`GeneratedFiles::Runner` は、Railsアプリ内で `generated_file_runs` テーブルが存在する場合、生成実行を記録します。

| 項目 | 内容 |
|---|---|
| `job_id` | 実行した生成JobID |
| `generator` | 使用したGenerator key |
| `output_writer` | 使用したOutputWriter key |
| `status` | running / completed / failed / skipped |
| `event_source` | manual_edit、external_folder_syncなどの呼び出し元 |
| `source_paths` | Job定義上の元ファイル |
| `changed_files` | イベントから渡された変更ファイル |
| `generated_paths` | 出力先パスまたはDocumentVersion参照 |
| `metadata` | 呼び出し元から渡された補足情報 |
| `error_message` | 失敗時のエラー |

GitHub ActionsやRails未起動のCLIでDBが使えない場合、記録はスキップされ、生成処理だけ実行されます。

## 重複・連続更新への対策

`GeneratedFileChangeEventJob` と `GeneratedFileJob` はSolid Queueのconcurrency制御を使います。

| Job | concurrency key |
|---|---|
| `GeneratedFileChangeEventJob` | 正規化した `path:operation` の組み合わせ |
| `GeneratedFileJob` | `job_ids` があればJobID、なければ変更ファイル一覧 |

これにより、同じファイルCRUDイベントや同じ生成JobIDの短時間多重実行を抑制します。

## GitHub Actionsとの関係

GitHub Actionsは、GitHub側の正本が変わった場合の安全網です。

`decision_flow.yml`、生成スクリプト、または `config/generated_file_jobs.yml` を更新してmainにpushすると、GitHub Actionsが該当ジョブを実行し、生成物に差分があれば `chore: update generated files` でmainへ自動コミットします。

アプリ内の `GeneratedFileJob` はdocs-portal側の作業ツリーまたはDocumentVersionを更新する責務を持ち、GitHubへのコミット・pushは行いません。

## 手動実行

初期データ投入や検証用途では、以下のRake入口を使えます。

```bash
CHANGED_FILES=storage/document_files/external_samples/ai-usecases/AI活用手順ポータル/data/decision_flow.yml bin/rails generated_files:enqueue
JOB_ID=ai_usecase_decision_flow bin/rails generated_files:enqueue_job
```

即時実行したい場合は `enqueue` の代わりに `run` / `run_job` を使います。

## PlantUMLを図として表示したい場合

`decision-flow.md` にはPlantUMLのソースをデフォルトで `text` コードブロックとして置きます。Kroki連携環境で図として表示したい場合は、以下の環境変数を付けて再生成します。

```bash
AI_USECASE_FLOW_DIAGRAM_LANGUAGE=plantuml bin/rails ai_usecases:generate_flow
```

## 他機能へ応用する方法

別のDSLやCSVから生成物を作る場合は、Generator classを追加し、`config/generated_file_jobs.yml` と `config/file_change_event_jobs.yml` に定義を追加します。

```yaml
# config/generated_file_jobs.yml
jobs:
  - id: sample_generator
    source_paths:
      - path/to/source.yml
    generator: sample_generator
    output_writer: document_version
    output_options:
      project_code: sample-project
      document_slug: sample-generated-document
      document_title: サンプル生成文書
    generated_paths:
      - document_versions/generated
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

## 将来の方向性

- 生成先をリポジトリ上のファイルではなく、DocumentVersion / storage / build artifact に寄せます。
- 後方互換の `command` 方式は段階的に減らし、Generator class方式に寄せます。
- `config/file_change_event_jobs.yml` の内容は、将来的にマスタメンテ画面から管理できる形にできます。その場合は、選択可能なJobやパラメーターをAllowListまたはmodel上のマッピングとして定義します。

## 注意点

- `decision-flow.md` は生成物です。直接編集せず、`data/decision_flow.yml` を編集します。
- docs-portalは当面GitHubへ書き込みません。
- GitHub Actionsの自動生成コミットの再帰実行を避けるため、`chore: update generated files` のコミットではworkflowを実行しません。
- Kroki未設定環境では `plantuml` / `d2` コードブロックがbuild失敗要因になるため、図化前のソースは `text` として置きます。
