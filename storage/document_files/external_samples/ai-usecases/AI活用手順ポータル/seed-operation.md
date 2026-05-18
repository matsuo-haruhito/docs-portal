---
title: seed運用メモ
---

# seed運用メモ

このページは、AI活用手順ポータルをdocs-portalのseedデータとして扱うための運用メモです。

## 配置場所

AI活用手順ポータルのMarkdownは、以下に配置します。

```text
storage/document_files/external_samples/
└── ai-usecases/
    └── AI活用手順ポータル/
        ├── README.md
        ├── usecases.md
        ├── tools-and-capabilities.md
        ├── patterns.md
        ├── decision-flow.md
        ├── data-model.md
        ├── seed-operation.md
        └── procedures/
            ├── PROC-CODE-GH-READ.md
            ├── PROC-CODE-LOCAL-READ.md
            ├── PROC-CODE-LOCAL-EDIT.md
            ├── PROC-CODE-GH-PR.md
            └── PROC-DOC-DRAFT.md
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

`decision-flow.md` にはPlantUMLのソース例を `text` コードブロックとして置いています。これはKroki未設定環境でseedやbuildが失敗しないようにするためです。

PlantUMLを実際に図としてレンダリングしたい場合は、Kroki endpointを設定したうえで、コードブロックの言語を `plantuml` に変更します。

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
| 判断フローを更新する | decision-flow.md |
| マスタ駆動生成に寄せる | data-model.md のYAML構造を正本化する |

## 将来的な生成処理

現時点では、Markdownを直接seed対象として配置しています。次の段階では、以下のように生成処理を追加できます。

```text
data/*.yml
  ↓
生成スクリプト
  ↓
README / usecases / tools / patterns / procedures / decision-flow
  ↓
external_samplesとしてseed
```

この段階まで進めると、1箇所のマスタ変更で手順書、索引、判断フローを再生成できるようになります。

## 注意点

- 手順書本文にツール名を直接埋め込みすぎると、ツール追加時の修正範囲が広がります。
- 手順書の正本をYAMLに寄せる場合は、Markdownは生成物として扱います。
- ただし、初期段階ではMarkdown直接管理のほうがレビューしやすく、seedにも載せやすいです。
- Kroki未設定環境では `plantuml` / `d2` コードブロックがbuild失敗要因になるため、図化前のソースは `text` として置きます。