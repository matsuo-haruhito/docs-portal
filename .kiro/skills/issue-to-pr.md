---
name: "issue解決"
description: "GitHub Issue を起点に、要件整理 → 実装 → PRライフサイクルまで一気通貫で進めるワークフロー"
---
# issue解決

GitHub Issue を起点に、要件整理 → 実装 → PR → マージまで一気通貫で進める。

## ワークフロー

### 1. Issue の確認

- `gh issue view <number>` で Issue の内容を読む
- Issue に書かれた課題・要望・バグの本質を理解する

### 2. 要件整理（必要に応じて）

要件・設計が実装に十分か判断し、不足していれば `issue整理` スキルの手順を実行する。

判断基準:
- **スキップ可**: Issue の記述が明確、1〜2ファイルの小修正、既存パターンの踏襲で済む
- **実行する**: 要件が曖昧、設計判断が必要、影響範囲が広い、テーブル変更を伴う

実行する場合は #[[file:.kiro/skills/issue-refine.md]] の手順に従う。
完了したらこのワークフローのステップ3に戻る。

### 3. 実装

- ブランチを切る: `git checkout -b issue-<number>-<slug>`
- コーディングルール（`.kiro/steering/coding.md`）と `docs/コーディング規約.md` に従って実装する
- テストは仕様確定済みの部分のみ書く
- コミットメッセージに `refs #<number>` を含める

### 4. PRライフサイクルへ

実装が完了したら、PRライフサイクル skill を自動的に実行する。
#[[file:.kiro/skills/pr-lifecycle.md]] の手順に従う。
PR本文には `Closes #<number>` を含めること。

### 5. 完了処理（PRマージ後）

- docs/ の関連文書を更新（必要に応じて）
- `docs/README.md` の索引を更新（新規文書を追加した場合）

## 使い方

```
Issue #42 をissue解決で
```

```
#42 のissue解決で進めて
```
