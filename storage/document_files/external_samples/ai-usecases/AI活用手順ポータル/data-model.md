---
title: マスタ駆動データ構造
---

# マスタ駆動データ構造

AI活用手順書は、手順本文を直接量産するのではなく、マスタとテンプレートから生成できる構造にします。

## 全体像

```text
業務ユースケース
  ↓
利用パターン
  ↓
AIツール + 能力
  ↓
手順テンプレート
  ↓
手順書本文
  ↓
判断フロー・索引
```

## 正本にするマスタ

| マスタ | 役割 | 変更例 |
|---|---|---|
| usecases | 業務・工程ごとのAI活用対象を定義する | 新しい工程や業務を追加する |
| tools | 会社で利用可能なAIツールを定義する | Claude Code、Gemini CLIなどを追加する |
| capabilities | AIツールが持つ能力を定義する | PR作成、CI確認、ローカル実行などを追加する |
| tool_capabilities | ツールと能力の対応を定義する | 既存ツールに新機能が追加された場合に更新する |
| patterns | ユースケースより細かい利用パターンを定義する | ローカル調査、GitHub調査、PR化などを追加する |
| procedures | ユースケース、パターン、AIツールの組み合わせを定義する | 手順IDを追加する |
| decision_rules | 目的や条件から手順IDを選ぶルールを定義する | 新しい分岐や推奨ツールを追加する |

## YAML化する場合の例

### tools.yml

```yaml
tools:
  - id: TOOL-CHATGPT
    name: ChatGPT
    type: conversation_ai
    environment: web_app
    capabilities:
      - CAP-DOC-SUMMARY
      - CAP-DOC-DRAFT
      - CAP-STRUCTURE

  - id: TOOL-CHATGPT-GH
    name: ChatGPT + GitHub App Connector
    type: conversation_ai_connector
    environment: web_app
    capabilities:
      - CAP-DOC-SUMMARY
      - CAP-DOC-DRAFT
      - CAP-STRUCTURE
      - CAP-CODE-READ
      - CAP-GITHUB
      - CAP-REVIEW

  - id: TOOL-CODEX-CLI
    name: Codex CLI
    type: coding_agent
    environment: local
    capabilities:
      - CAP-CODE-READ
      - CAP-CODE-EDIT
      - CAP-LOCAL
      - CAP-TEST
      - CAP-REVIEW

  - id: TOOL-CODEX-WEB
    name: Codex Web/App
    type: coding_agent
    environment: web_app
    capabilities:
      - CAP-CODE-READ
      - CAP-CODE-EDIT
      - CAP-GITHUB
      - CAP-PR
      - CAP-CI
      - CAP-REVIEW
```

### patterns.yml

```yaml
patterns:
  - id: PAT-CODE-GH-READ
    name: GitHub上のコード解析
    required_capabilities:
      - CAP-CODE-READ
      - CAP-GITHUB
    outputs:
      - 調査メモ
      - 影響範囲一覧
      - 確認事項

  - id: PAT-CODE-LOCAL-EDIT
    name: ローカル複数ファイル修正
    required_capabilities:
      - CAP-CODE-READ
      - CAP-CODE-EDIT
      - CAP-LOCAL
      - CAP-TEST
    outputs:
      - 差分
      - テスト結果
      - 修正メモ
```

### procedures.yml

```yaml
procedures:
  - id: PROC-CODE-GH-READ
    usecase_id: UC-CODE-001
    pattern_id: PAT-CODE-GH-READ
    tool_id: TOOL-CHATGPT-GH
    title: GitHub Connectorで既存コードを調査する
    outputs:
      - 調査メモ
      - 影響範囲一覧
      - 確認事項

  - id: PROC-CODE-LOCAL-EDIT
    usecase_id: UC-IMPL-002
    pattern_id: PAT-CODE-LOCAL-EDIT
    tool_id: TOOL-CODEX-CLI
    title: Codex CLIで複数ファイルを修正する
    outputs:
      - 差分
      - テスト結果
```

### decision_rules.yml

```yaml
decision_rules:
  - id: RULE-001
    priority: 10
    when:
      target: 文書
    recommend:
      procedure_id: PROC-DOC-DRAFT

  - id: RULE-020
    priority: 20
    when:
      target: コード
      edit: false
      location: github
    recommend:
      procedure_id: PROC-CODE-GH-READ

  - id: RULE-030
    priority: 30
    when:
      target: コード
      edit: true
      location: local
    recommend:
      procedure_id: PROC-CODE-LOCAL-EDIT
```

## 生成されるもの

| 生成物 | 内容 |
|---|---|
| 手順書Markdown | procedures.yml とテンプレートから作る |
| 目的別索引 | usecases と decision_rules から作る |
| ツール別索引 | tools と procedures から作る |
| 判断フローMarkdown | decision_rules から作る |
| PlantUML | decision_rules から作る |

## Excelとの関係

Excelは以下の用途に限定すると管理しやすくなります。

- 初期棚卸し
- 一覧での確認
- マスタの一括編集
- レビュー用の表形式出力

正本はCSVまたはYAMLに寄せ、docs-portalではMarkdownとして閲覧できるようにします。

## 更新時の原則

| 変更したいこと | 変更箇所 |
|---|---|
| 新しいAIツールを追加する | tools / tool_capabilities |
| 既存AIに新機能が追加された | tool_capabilities |
| 新しい業務ユースケースを追加する | usecases |
| 新しい使い方の型を追加する | patterns |
| 新しい具体手順を追加する | procedures |
| 目的からの導線を変える | decision_rules |
| 手順文言を変える | procedure_templates または該当手順 |

この分離により、1箇所の変更で関連する手順書、索引、判断フローを再生成できる状態を目指します。