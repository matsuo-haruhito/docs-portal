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

YAMLを変更したら、以下を実行してMarkdownとPlantUMLを再生成します。

```bash
bin/rails ai_usecases:generate_flow
```

Rails環境を通さずに生成スクリプトだけ実行する場合は以下です。

```bash
ruby bin/generate_ai_usecase_flow
```

生成されるファイルは以下です。

| 生成物 | 用途 |
|---|---|
| `storage/document_files/external_samples/ai-usecases/AI活用手順ポータル/decision-flow.md` | seedで取り込む判断フロー本文 |
| `docs/ai-usecases/generated/decision-flow.puml` | PlantUMLソースの単体ファイル |

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

## 今後の拡張

| やりたいこと | 追加・変更箇所 |
|---|---|
| 新しいAIツールを追加する | tools-and-capabilities.md、将来的には tools.yml |
| 新しい能力を追加する | tools-and-capabilities.md、将来的には capabilities.yml |
| 新しいユースケースを追加する | usecases.md |
| 新しい利用パターンを追加する | patterns.md |
| 新しい手順書を追加する | procedures/ 配下にMarkdownを追加 |
| 判断フローを更新する | data/decision_flow.yml を変更して `bin/rails ai_usecases:generate_flow` を実行 |
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
- 手順書本文にツール名を直接埋め込みすぎると、ツール追加時の修正範囲が広がります。
- 手順書の正本をYAMLに寄せる場合は、Markdownは生成物として扱います。
- Kroki未設定環境では `plantuml` / `d2` コードブロックがbuild失敗要因になるため、図化前のソースは `text` として置きます。