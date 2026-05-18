---
title: 利用パターン一覧
---

# 利用パターン一覧

ユースケースをそのまま手順書にすると、同じ「コード解析」でもツールや状況によって手順が変わります。そのため、ユースケースより一段細かい利用パターンを定義します。

| PatternID | パターン名 | 対象 | 目的 | 必要能力 | 主な入力 | 主な成果物 |
|---|---|---|---|---|---|---|
| PAT-DOC-DRAFT | 資料ドラフト作成 | 文書 | 提案資料、設計書、報告文のたたき台を作る | CAP-DOC-DRAFT, CAP-STRUCTURE | メモ、議事録、既存資料 | ドラフト、章立て、表 |
| PAT-DOC-SUMMARY | 情報整理・要約 | 文書 | 顧客情報、議事録、過去資料を要約・分類する | CAP-DOC-SUMMARY, CAP-STRUCTURE | 文字起こし、メモ、資料 | 要約、論点、ToDo |
| PAT-CODE-GH-READ | GitHub上のコード解析 | コード | GitHub上の既存コードから仕様や影響範囲を把握する | CAP-CODE-READ, CAP-GITHUB | repo, branch, path, Issue, PR | 調査メモ、影響範囲一覧 |
| PAT-CODE-LOCAL-READ | ローカルコード解析 | コード | 手元の作業コピーや未コミット差分を含めて調査する | CAP-CODE-READ, CAP-LOCAL | local path, branch, diff | 調査メモ、対象ファイル一覧 |
| PAT-CODE-LOCAL-EDIT | ローカル複数ファイル修正 | コード | ローカルで複数ファイルを修正し、テストする | CAP-CODE-READ, CAP-CODE-EDIT, CAP-LOCAL, CAP-TEST | local path, 要件, エラー内容 | 差分、テスト結果 |
| PAT-CODE-GH-PR | GitHub上で修正してPR化 | コード | GitHub上でIssueや要件に基づき修正し、PRを作成する | CAP-CODE-READ, CAP-CODE-EDIT, CAP-GITHUB, CAP-PR | repo, Issue, branch | PR、変更概要、CI結果 |
| PAT-REVIEW-PR | PRレビュー | コード | PR差分を読み、レビューコメントや追加確認事項を作る | CAP-CODE-READ, CAP-GITHUB, CAP-REVIEW | PR, diff, 設計観点 | レビューコメント、指摘一覧 |
| PAT-CI-INVESTIGATE | CI失敗調査 | コード | CIログを読み、失敗原因と修正方針を整理する | CAP-CI, CAP-CODE-READ, CAP-TEST | CIログ, PR, commit | 原因候補、修正方針 |
| PAT-ISSUE-BREAKDOWN | Issue・タスク分解 | 管理 | 要件や設計から実装タスク・Issueに分解する | CAP-DOC-DRAFT, CAP-STRUCTURE | 要件、設計、議事録 | Issue案、タスク一覧 |

## パターンとツールの関係

利用パターンは、特定ツールに固定しません。たとえば `PAT-CODE-GH-READ` は、主に `ChatGPT + GitHub App Connector` に向いていますが、状況によっては `Codex Web/App` でも実行できます。

| PatternID | 主候補 | 代替候補 | 切り替え条件 |
|---|---|---|---|
| PAT-CODE-GH-READ | ChatGPT + GitHub App Connector | Codex Web/App | 調査だけならChatGPT、修正やPR化に進むならCodex Web/App |
| PAT-CODE-LOCAL-READ | Codex CLI | ChatGPT | ローカル差分や多数ファイルがあるならCodex CLI、抜粋コードだけならChatGPT |
| PAT-CODE-LOCAL-EDIT | Codex CLI | Codex Web/App | ローカルテストが必要ならCodex CLI、GitHub上で完結するならCodex Web/App |
| PAT-CODE-GH-PR | Codex Web/App | Codex CLI | GitHub上でPR化するならCodex Web/App、手元で実装してからpushするならCodex CLI |
| PAT-DOC-DRAFT | ChatGPT | Codex CLI / Codex Web/App | コードやREADMEと整合させたい場合はCodex系も候補 |

## 更新方針

新しいAIツールが増えた場合は、利用パターンを増やすのではなく、まず既存パターンに必要な能力を満たせるか確認します。既存パターンで表現できない新しい使い方だけ、新しいPatternIDとして追加します。