# docs

このディレクトリは、この repo で運用する仕様・規約・方針の置き場です。

## 最初に読む

1. [Product Profile](../Product%20Profile.md)
2. [アプリケーション仕様](./アプリケーション仕様.md)
3. [テスト方針](./テスト方針.md)
4. [開発・保守ガイド](./開発・保守ガイド.md)

## カテゴリ別入口

### 仕様 → [specs/](./specs/)

機能仕様、API仕様、データモデル設計

### Runbook → [runbooks/](./runbooks/)

操作手順（viewer / admin / import / 外部連携 / 運用インフラ）

### 開発ガイド → [guides/](./guides/)

セットアップ手順、開発フロー

### gem 連携 → [internal-ui-gem/](./internal-ui-gem/)

tree_view / rails_table_preferences / rails_fields_kit のリリース判断・evidence

### 未確定事項 → [ToDo.md](./ToDo.md)

### AI 向けルール・実装ガイド → [.kiro/](../.kiro/)

steering（ルール）と skills（手順）は .kiro/ 配下を参照

---

## その他のサブディレクトリ

- [ai-usecases/](./ai-usecases/) — AI ユースケース生成物（PlantUML 等の自動生成出力先）
- [notes/](./notes/) — 技術メモ（Docusaurus runtime、調査、preview ロードマップ）
- [qa/](./qa/) — QA チェックリスト

---

## 規約・方針（docs/ 直下）

- [コーディング規約](./コーディング規約.md)
- [テスト方針](./テスト方針.md)
- [開発・保守ガイド](./開発・保守ガイド.md)

---

## 関連リンク

- [ROADMAP](../ROADMAP.md) — gem 展開・Stimulus 化の次フェーズ
- [maintenance-mode 境界一覧](../.kiro/steering/maintenance-mode-boundaries.md)
- [internal UI gem 責務境界](../.kiro/steering/internal-ui-gem-boundaries.md)
- [フロントエンド操作の方針](../.kiro/steering/frontend-interaction-policy.md)
