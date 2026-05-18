---
title: AI活用手順ポータル
---

# AI活用手順ポータル

このサンプル文書サイトは、システム開発全体におけるAI活用ユースケースを、docs-portal上で手順書として探せるようにするための seed データです。

## 目的

AIツールや機能が増えても、手順書を個別に書き直さずに済むよう、以下を分離して管理します。

| 管理対象 | 役割 |
|---|---|
| 業務ユースケース | どの業務でAIを使うかを定義する |
| AIツール | ChatGPT、GitHub Connector、Codex CLI、Codex Web/App などを定義する |
| 能力 | コード参照、コード編集、PR作成、ローカル対応、資料作成などを定義する |
| 利用パターン | ユースケースを実際の使い方の型に分解する |
| 手順書 | ユースケース、パターン、AIツールの組み合わせで定義する |
| 判断フロー | 目的や状況から該当手順を探す導線を定義する |

## 基本方針

- Excelは一覧確認・初期整理・マスタ編集補助として使う。
- docs-portalは公開・検索・閲覧・手順書化の正本として使う。
- 手順書は直接量産せず、できるだけマスタやテンプレートから生成できる構造にする。
- 新しいAIツールが増えた場合は、AIツールマスタと能力定義を追加するだけで候補に出せる状態を目指す。
- 判断フローはMarkdown本文とPlantUMLの両方で表現できるようにする。

## seedで取り込まれる主なページ

| ページ | 内容 |
|---|---|
| usecases.md | 業務ユースケース一覧 |
| tools-and-capabilities.md | AIツールと能力マトリクス |
| patterns.md | 利用パターン一覧 |
| decision-flow.md | 目的から手順書を探す判断フロー |
| data-model.md | マスタ駆動・生成型にするためのデータ構造 |
| procedures/*.md | ユースケース、パターン、AIツール単位の詳細手順書 |

## 想定する使い方

1. まず目的を確認する。
2. 判断フローで対象が「文書」「コード」「会議」「設計」「テスト」などのどれかを選ぶ。
3. コードを扱う場合は、ローカルにコードがあるか、GitHub上で読むか、修正やPR化まで行うかを選ぶ。
4. 該当する手順IDを開く。
5. 手順書の前提条件、入力、手順、成果物、切り替え条件を確認する。

## 現時点の代表手順

| 手順ID | 手順名 | 主なツール |
|---|---|---|
| PROC-CODE-GH-READ | GitHub Connectorで既存コードを調査する | ChatGPT + GitHub App Connector |
| PROC-CODE-LOCAL-READ | Codex CLIでローカルコードを調査する | Codex CLI |
| PROC-CODE-LOCAL-EDIT | Codex CLIで複数ファイルを修正する | Codex CLI |
| PROC-CODE-GH-PR | Codex Web/AppでGitHub上の修正をPR化する | Codex Web/App |
| PROC-DOC-DRAFT | ChatGPTで資料ドラフトを作成する | ChatGPT |

## 運用メモ

この文書群は `storage/document_files/external_samples` 配下に置くことで、既存の seed 処理から Project / Document / DocumentVersion として取り込まれます。PlantUMLを含むページをDocusaurus buildする場合は、Kroki endpoint の設定が必要です。