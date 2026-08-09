# docs/internal-ui-gem/

internal UI gem（tree_view / rails_table_preferences / rails_fields_kit）のリリース判断・evidence 記録に使う人間向け文書の集約ディレクトリです。

AI 向けの責務境界ルールは [.kiro/steering/internal-ui-gem-boundaries.md](../../.kiro/steering/internal-ui-gem-boundaries.md)、bump/smoke 手順は [.kiro/skills/internal-ui-gem-workflow.md](../../.kiro/skills/internal-ui-gem-workflow.md) を参照してください。

## 文書一覧

| 文書 | 目的 | 参照タイミング |
|------|------|---------------|
| [adoption-evidence-map.md](./adoption-evidence-map.md) | 代表 smoke、upstream evidence、確認順、rollback note の入口 map | release train の bump PR 作成時 / evidence 記録時 |
| [関連gem採用マトリクス.md](./関連gem採用マトリクス.md) | 3 gem の画面別採用状況・責務分担の横断比較表 | gem 責務の切り分け判断時 / 新画面への gem 適用検討時 |
| [state-cue-inventory.md](./state-cue-inventory.md) | 3 gem の状態表示 cue の意味と責務境界の読み合わせ inventory | gem 間の cue 統一・新画面の状態表示設計時 |
