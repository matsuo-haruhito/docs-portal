# Preview UX roadmap

この文書は、Markdown / Docusaurus preview、版差分、添付・元ファイル viewer、検索、codeblock actions 周辺の改善ロードマップを整理する。

関連仕様の入口は [Specs index](../specs/README.md) を参照する。

## 短期タスク

### 1. Preview target metadata display refinement

目的:

- 可視化済みの分類情報を、実際の添付・元ファイル閲覧体験に合わせて整える

完了条件:

- hidden 分類のファイルが通常一覧から分離（非表示 or 折りたたみ）され、debug 分類が専用セクションに表示され、group_name でフィルタまたはグルーピングが動作すること

候補:

- hidden を通常一覧から除外または折りたたみ領域に移す
- debug を debug セクションとして分ける
- group_name による絞り込み / grouping を検討する
- UI は既存表示を壊さない小さい差分で段階的に行う

### 2. specs / roadmap の継続整理

目的:

- 実装済みの preview 改善と仕様書の差分を小さく保つ

完了条件:

- 仕様ファイル追加時に specs/README.md へリンクが追加され、実装済みタスクが roadmap から除去されていること

候補:

- 仕様ファイル追加時に `docs/specs/README.md` へリンクする
- 実装済みタスクを roadmap から削除 / 移動する
- research と仕様の参照関係を整理する

※ 具体情報待ち — 対象・手段が未定のため着手不可

## 中期タスク

### 1. Docusaurus build profiles の明示化

目的:

- portal embedded / admin API spec / preview check / diff metadata の用途を分ける

完了条件:

- build command が profile 引数を受け付け、manifest に profile / source commit / build time が記録され、stale build warning が viewer shell に表示されること

候補:

- build command に profile を渡す
- build manifest を保存する
- manifest に profile / source commit / build time / validation result を含める
- stale build / profile mismatch warning を viewer shell に表示する

### 2. Path history / redirect 実装

目的:

- slug / site path / tree path 変更時に旧URL互換を保つ

完了条件:

- path history model が変更履歴を保持し、旧 URL アクセスで canonical path へリダイレクトされ、deleted/archived notice が表示されること

候補:

- path history model
- canonical path resolver
- moved / archived / deleted notice
- 旧 path 参照の品質チェック warning
- slug / path 変更 dry-run

### 3. Codeblock action のレビューコメント接続

目的:

- code block の行 anchor と internal review comment を接続する

完了条件:

- codeblock line からコメント追加を開始でき、コメント一覧から該当行へジャンプできること

候補:

- comment form に codeblock anchor を入れられるようにする
- codeblock line からコメント追加を開始できるようにする
- コメント一覧から該当 codeblock line へ移動する

### 4. Portal 横断検索の第一歩

※ 具体情報待ち — 対象・手段が未定のため着手不可
