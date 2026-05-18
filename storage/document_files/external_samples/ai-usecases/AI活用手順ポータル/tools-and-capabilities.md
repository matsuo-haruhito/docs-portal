---
title: AIツールと能力マトリクス
---

# AIツールと能力マトリクス

AIツールの追加や機能拡張に追従しやすくするため、ツール名ではなく能力を軸に整理します。

## AIツールマスタ

| ToolID | ツール名 | 種別 | 実行場所 | 主な用途 | 備考 |
|---|---|---|---|---|---|
| TOOL-CHATGPT | ChatGPT | 会話AI | Web/App | 情報整理、要約、資料作成、壁打ち | コード編集やPR作成は主用途ではない |
| TOOL-CHATGPT-GH | ChatGPT + GitHub App Connector | 会話AI + Connector | Web/App | GitHub上のコード、Issue、PRを会話形式で調査 | ローカル未コミット差分は対象外 |
| TOOL-CODEX-CLI | Codex CLI | Coding Agent | ローカル | ローカルコード調査、複数ファイル修正、テスト実行 | 手元の作業ブランチや未コミット差分を扱いやすい |
| TOOL-CODEX-WEB | Codex Web/App | Coding Agent | Web/App | GitHub上の修正、PR作成、CI確認 | ローカル専用ファイルの扱いには向かない |

## 能力マスタ

| CapabilityID | 能力名 | 説明 |
|---|---|---|
| CAP-DOC-SUMMARY | 文書要約 | 議事録、メモ、資料を要約する |
| CAP-DOC-DRAFT | 文書生成 | 提案書、設計書、手順書、報告文のドラフトを作る |
| CAP-STRUCTURE | 構造化 | 箇条書き、表、章立て、分類に整理する |
| CAP-CODE-READ | コード参照 | ソースコード、設定、テスト、READMEを読む |
| CAP-CODE-EDIT | コード編集 | 既存コードを修正、新規ファイルを追加する |
| CAP-LOCAL | ローカル対応 | ローカルの作業コピー、未コミット差分、ローカルテストを扱う |
| CAP-GITHUB | GitHub接続 | GitHub上のリポジトリ、Issue、PR、差分を扱う |
| CAP-PR | PR作成 | ブランチ作成、コミット、Pull Request作成を行う |
| CAP-TEST | テスト実行 | ローカルまたはCI上でテスト・lintを確認する |
| CAP-CI | CI確認 | GitHub ActionsなどのCI結果を確認する |
| CAP-REVIEW | レビュー | PR差分や設計観点からレビューコメントを作る |

## ツール能力マトリクス

| ToolID | CAP-DOC-SUMMARY | CAP-DOC-DRAFT | CAP-STRUCTURE | CAP-CODE-READ | CAP-CODE-EDIT | CAP-LOCAL | CAP-GITHUB | CAP-PR | CAP-TEST | CAP-CI | CAP-REVIEW |
|---|---|---|---|---|---|---|---|---|---|---|---|
| TOOL-CHATGPT | ○ | ○ | ○ | △ | × | × | × | × | × | × | △ |
| TOOL-CHATGPT-GH | ○ | ○ | ○ | ○ | △ | × | ○ | × | × | △ | ○ |
| TOOL-CODEX-CLI | △ | △ | △ | ○ | ○ | ○ | △ | △ | ○ | × | ○ |
| TOOL-CODEX-WEB | △ | △ | △ | ○ | ○ | × | ○ | ○ | △ | ○ | ○ |

## 使い分けの考え方

| 状況 | 候補ツール |
|---|---|
| 情報整理、議事録、提案資料のたたき台を作る | ChatGPT |
| GitHub上のコードを読み、仕様や影響範囲を会話で確認する | ChatGPT + GitHub App Connector |
| ローカルにあるコードや未コミット差分を読ませる | Codex CLI |
| ローカルで複数ファイルを修正し、テストも実行する | Codex CLI |
| GitHub上でIssue起点に修正してPR化する | Codex Web/App |
| PR差分、レビューコメント、CI結果まで含めて扱う | Codex Web/App |

## 更新方針

会社で使えるAIが増えた場合は、まずAIツールマスタにToolIDを追加し、能力マトリクスに対応能力を追加します。手順書本文に直接ツール名を埋め込むのではなく、ToolIDとCapabilityIDで紐づけることで、差し替えや追加に強くします。