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
| `config/generated_file_jobs.yml` | GeneratedFileJobが実行する生成JobID、生成コマンド、生成物の定義 |
| `.github/workflows/generated-file-jobs.yml` | GitHub push時に `config/generated_file_jobs.yml` を読んで生成物を更新する安全網 |
| `app/services/generated_files/change_event_handler.rb` | CRUDイベントを受け取り、`config/file_change_event_jobs.yml` に従ってJobをenqueueする共通ハンドラ |
| `app/jobs/generated_file_change_event_job.rb` | 外部同期、手修正、アップロードなどから呼ぶファイル変更イベント用ActiveJob |
| `app/services/generated_files/runner.rb` | `config/generated_file_jobs.yml` を読み、生成コマンドを実行する共通サービス |
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
    command: ruby bin/generate_ai_usecase_flow
    generated_paths:
      - storage/document_files/external_samples/ai-usecases/AI活用手順ポータル/decision-flow.md
      - docs/ai-usecases/generated/decision-flow.puml
```

現時点では `command` 方式ですが、将来的にはshellではなくGenerator class方式に寄せる想定です。

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

アプリ内の `GeneratedFileJob` はdocs-portal側の作業ツリー上の生成物を更新する責務を持ち、GitHubへのコミット・pushは行いません。

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

別のDSLやCSVから生成物を作る場合は、`config/generated_file_jobs.yml` に生成コマンドを追加し、`config/file_change_event_jobs.yml` にCRUDイベントから起動するJob定義を追加します。

```yaml
# config/generated_file_jobs.yml
jobs:
  - id: sample_generator
    source_paths:
      - path/to/source.yml
    command: ruby bin/generate_sample
    generated_paths:
      - path/to/generated.md
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
- `command` 方式はGenerator class方式に置き換えていきます。
- `config/file_change_event_jobs.yml` の内容は、将来的にマスタメンテ画面から管理できる形にできます。その場合は、選択可能なJobやパラメーターをAllowListまたはmodel上のマッピングとして定義します。

## 注意点

- `decision-flow.md` は生成物です。直接編集せず、`data/decision_flow.yml` を編集します。
- docs-portalは当面GitHubへ書き込みません。
- GitHub Actionsの自動生成コミットの再帰実行を避けるため、`chore: update generated files` のコミットではworkflowを実行しません。
- Kroki未設定環境では `plantuml` / `d2` コードブロックがbuild失敗要因になるため、図化前のソースは `text` として置きます。
