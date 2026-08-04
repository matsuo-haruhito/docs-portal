# プロジェクト固有テーマ

inclusion: always

このファイルは docs-portal 固有の「全画面に共通で備える機能・トーン」を定義する。

---

## プロダクトコンセプト

文書配布ポータル（docs-portal）— 案件ごとの社外秘ドキュメント配布を Rails + Docusaurus で運用するためのポータルアプリ。

### 対象ユーザー

- internal admin / staff（案件、文書、権限、公開状態、運用ジョブ、外部連携を管理する）
- external user（許可された案件と文書を閲覧し、添付ファイルをダウンロードする）
- company_master_admin（自社の会社 / ユーザー管理のみ）

### トーン

- 管理画面は情報密度高め — テーブル+フィルタ+エクスポートのフル装備
- 公開側は最小限の導線で目的の文書に辿り着ける
- 日本語完結 — 英語ラベルが画面に出ない

---

## 全画面共通の設計テーマ

### 一覧画面のフル装備

管理画面の一覧画面には以下を標準装備する:
- rails_table_preferences (rtp) による列設定・ソート・フィルタ
- rails_fields_kit (rfk) による検索フォーム
- CSV エクスポート
- rparam によるフィルタ条件のセッション記憶
- ページネーション

### ツリー表示

文書のツリー構造表示には tree_view-rails を使用する。

### public_id によるURL設計

外部URLには DB の連番 id を露出させず、public_id / slug / code を使う。

---

## 権限モデルの画面設計

### internal admin

- `/admin` 配下の全管理機能にアクセス可能
- 案件、文書、権限、運用ジョブ、外部連携を操作

### company_master_admin

- `/admin` の「会社」「ユーザー」管理のみ
- 他の admin surface にはアクセス不可

### external user

- 許可された案件と文書のみ閲覧
- 添付ファイルのダウンロード（権限に応じて）
- アクセス申請

---

## Import / Build / 外部連携

### 共通の設計原則

- dry-run → レビュー → 実行 の段階的フロー
- 結果は成功 / 失敗 / 部分成功を明示
- version immutability（一度 import した版は変更不可）

### 外部フォルダ同期

- provider-aware（Google Drive / SharePoint）
- 片方向取り込み（portal への import のみ）
- 安全判定 + 競合警告 の後に適用
