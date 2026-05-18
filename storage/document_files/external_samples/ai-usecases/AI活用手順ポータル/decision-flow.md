---
title: 目的から探す判断フロー
---

# 目的から探す判断フロー

このページは、目的や作業状況から該当する手順書を探すための入口です。

## まず確認すること

| 判断項目 | Yesの場合 | Noの場合 |
|---|---|---|
| コードを扱うか | コード関連フローへ進む | 文書・業務整理フローへ進む |
| コードを修正するか | 修正・PR化フローへ進む | コード解析フローへ進む |
| ローカルにコードがあるか | Codex CLI候補 | GitHub Connector / Codex Web/App候補 |
| GitHub上でPR化したいか | Codex Web/App候補 | Codex CLIまたはChatGPT候補 |
| テスト実行が必要か | Codex CLI候補 | ChatGPT / Codex Web/App候補 |
| 顧客向け・社内向け文書が必要か | ChatGPT候補 | Codex候補 |

## 文書・資料を作りたい

| 状況 | 推奨手順 |
|---|---|
| 議事録、メモ、過去資料を整理したい | PROC-DOC-DRAFT または情報整理系手順 |
| 提案資料や設計書のたたき台を作りたい | PROC-DOC-DRAFT |
| コードやREADMEと整合する文書を作りたい | コード解析手順を先に実施してから PROC-DOC-DRAFT |

## コードを読みたい

| 状況 | 推奨手順 |
|---|---|
| GitHub上のコードを会話形式で調査したい | PROC-CODE-GH-READ |
| ローカルにあるコード、作業ブランチ、未コミット差分を調査したい | PROC-CODE-LOCAL-READ |
| 調査後に修正やPR化も必要になりそう | PROC-CODE-GH-PR または PROC-CODE-LOCAL-EDIT |

## コードを修正したい

| 状況 | 推奨手順 |
|---|---|
| ローカルにコードがあり、テストも実行したい | PROC-CODE-LOCAL-EDIT |
| GitHub上でIssueをもとに修正し、PR化したい | PROC-CODE-GH-PR |
| まず実装方針だけ相談したい | ChatGPTまたはPROC-CODE-GH-READで方針整理 |

## PlantUMLソース例

以下は判断フローを図にするためのPlantUMLソース例です。Kroki連携環境では `plantuml` コードブロックとして配置すると図化できます。

```text
@startuml
start
:目的を確認する;
if (コードを扱う?) then (Yes)
  if (コードを修正する?) then (Yes)
    if (ローカルにコードがある?) then (Yes)
      :PROC-CODE-LOCAL-EDIT\nCodex CLIで複数ファイル修正;
    else (No)
      if (PR作成まで必要?) then (Yes)
        :PROC-CODE-GH-PR\nCodex Web/AppでPR作成;
      else (No)
        :PROC-CODE-GH-READ\nGitHub Connectorで調査;
      endif
    endif
  else (No)
    if (ローカルにコードがある?) then (Yes)
      :PROC-CODE-LOCAL-READ\nCodex CLIでローカル調査;
    else (No)
      :PROC-CODE-GH-READ\nGitHub Connectorで調査;
    endif
  endif
else (No)
  :PROC-DOC-DRAFT\nChatGPTで資料ドラフト作成;
endif
stop
@enduml
```

## ルール化する場合の考え方

判断フローは、将来的には以下のようなルールマスタから生成します。

| RuleID | 優先度 | 条件項目 | 条件値 | 推奨PatternID | 推奨ToolID | 推奨手順ID |
|---|---:|---|---|---|---|---|
| RULE-001 | 10 | 対象 | 文書 | PAT-DOC-DRAFT | TOOL-CHATGPT | PROC-DOC-DRAFT |
| RULE-010 | 10 | 対象 | コード |  |  | 次の質問へ |
| RULE-020 | 20 | 修正有無 | いいえ | PAT-CODE-GH-READ | TOOL-CHATGPT-GH | PROC-CODE-GH-READ |
| RULE-030 | 30 | ローカル有無 | はい | PAT-CODE-LOCAL-EDIT | TOOL-CODEX-CLI | PROC-CODE-LOCAL-EDIT |
| RULE-040 | 40 | PR必要 | はい | PAT-CODE-GH-PR | TOOL-CODEX-WEB | PROC-CODE-GH-PR |

## 更新方針

判断フローは手書きで複雑化させず、条件、利用パターン、AIツール、手順IDの対応表として管理します。新しいツールや能力が増えた場合は、ルールと能力マトリクスを更新して、フロー本文や図を再生成します。