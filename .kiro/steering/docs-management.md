# ドキュメント運用ルール

inclusion: always

---

## docs/ と .kiro/ の使い分け

| 置き場 | 主な読者 | 内容 |
|--------|---------|------|
| `docs/` | 人間（開発者・レビュアー） | 仕様、runbook、設計メモ、セットアップ手順 |
| `.kiro/steering/` | AI（Kiro） | コーディングルール、UI設計パターン、gem利用方針 |
| `.kiro/skills/` | AI（Kiro） | 実装ガイド（rfk/rtp等）、ワークフロー |

### 配置ルール

- 人間が主に読むドキュメント → `docs/` に配置する
- AIが主に参照するドキュメント → `.kiro/` に配置する
- 両方が読む場合 → 比重が高い方に正本を置き、もう一方からリンクで参照する
- **二重管理は避ける**。同じ内容を両方に書かない

---

## SSOT（Single Source of Truth）規律

| 情報 | 正本 |
|------|------|
| 業務仕様・要件（恒久） | `docs/specs/` + `docs/アプリケーション仕様.md`（インデックス） |
| 実装計画（一時） | `.kiro/specs/{feature}/`（完了後削除） |
| コーディングルール | `.kiro/steering/coding.md` |
| テスト方針 | `docs/テスト方針.md` |
| UI設計パターン | `.kiro/steering/ui-patterns.md` |
| rfk/rtp/tree_view 利用方針 | `.kiro/steering/rfk-rtp-integration.md` |
| rfk/rtp 実装例 | `.kiro/skills/rfk-usage.md`, `.kiro/skills/rtp-usage.md` |
| テーブル構造 | `db/schema.rb` + マイグレーション |
| ビジネスロジック | コード（`app/` 配下）が正本 |
| repo の位置づけ | `Product Profile.md` |
| docs 索引 | `docs/README.md` |
| 将来対応・保留事項 | `docs/ToDo.md` |
| フロントエンド操作方針 | `.kiro/steering/frontend-interaction-policy.md` |
| maintenance-mode 境界 | `.kiro/steering/maintenance-mode-boundaries.md` |
| gem 責務境界・判断基準 | `.kiro/steering/internal-ui-gem-boundaries.md` |
| 公開 API 仕様（Docusaurus build 用 Markdown） | `docs-src/*.md` |
| 画面仕様ドキュメント生成 | `.kiro/steering/screen-docs.md` |
| 画面シナリオ定義（正本） | `script/screenshot_scenarios.ts` |
| 画面仕様ガイド（自動生成） | `docs/screen_guide.md`（直接編集禁止） |

**重複が生じたら正本を1つ選び、他はポインタ（リンク）に置き換える。**

---

## コード変更時のドキュメント更新

コードを変更した場合、以下を確認し乖離があれば修正する:

1. **docs/ の該当文書**: 実装した内容が仕様として記載されているか。記載がなければ追記する
2. **.kiro/steering/coding.md**: 新しいパターンを導入した場合、コーディングルールとして明文化すべきか検討する
3. **.kiro/steering/**: AIが守るべきルールに影響する変更があれば、steering も更新する
4. **.kiro/skills/**: rfk/rtp/tree_view の使い方を変えたら skill も同時更新する（`rfk-rtp-integration.md` の追従ルール）

### docs/ に新規文書を追加した場合

- `docs/README.md` の索引も同一ターンで更新する

---

## 設計変更の反映順序

設計判断を変える場合は以下の順序を守る:

1. `docs/` の該当文書を更新する
2. 関連するテストを更新する（あれば）
3. コードを変更する
4. `.kiro/` の steering / skill に影響があれば更新する

**コードを先に変えてからドキュメントを追従させるのは原則禁止。**
ただし、バグ修正や小さなリファクタなど設計判断を変えないコード変更はこの限りではない。

---

## spec 配置ルール

| 置き場 | 役割 | ライフサイクル |
|--------|------|---------------|
| `docs/specs/` | プロジェクト全体の恒久仕様・設計（人間が読む正本） | 永続。実装と乖離したら更新する |
| `.kiro/specs/{feature}/` | Kiro spec セッション用の実装計画（requirements.md / design.md / tasks.md） | 実装完了後に削除する |

### ルール

- 恒久的な仕様・設計判断は `docs/specs/` に書く
- Kiro の spec セッションで生成する実装計画は `.kiro/specs/{feature}/` に置く
- `.kiro/specs/` の実装計画が完了したら、仕様として残すべき内容は `docs/specs/` に反映し、計画ファイル自体は削除する
- `docs/アプリケーション仕様.md` は機能名 + 概要のインデックスとして維持する

---

## ドキュメント品質の基準

### 残すべき情報

- 現在有効な仕様・設計判断
- 操作手順（runbook）
- repo 固有の制約や注意点
- 「なぜこうしているか」の判断理由

### 残さないべき情報

- 実装と乖離した古い記述（発見次第修正 or 削除する）
- 歴史的経緯だけの記述（git履歴で参照する）
- コードを読めば明らかなことの重複記載

### 整理の指針

- 整理されず雑然と残っている情報はゴミと同じ。定期的に棚卸しし、不要なものは消す
- 古い判断・完了した移行方針は削除する（現状の事実だけ残す）
