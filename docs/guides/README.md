# 開発ガイド

ローカル開発環境のセットアップから、seed データの確認、ポータル更新までの開発者向けガイドを集めたディレクトリです。

## ファイル一覧

- [ローカルセットアップと環境変数](./ローカルセットアップと環境変数.md) — `.env.example` を基準にした最短起動手順と環境変数の役割
- [ローカル編集からポータル更新までの最小運用案](./ローカル編集からポータル更新までの最小運用案.md) — ローカル編集から git push → GitHub Actions → ポータル更新までの最小フロー
- [標準seedサンプルと確認用途](./標準seedサンプルと確認用途.md) — repo 標準 showcase、ai-usecases、任意 external_samples の違いと確認観点
- [任意external_samples事前検証dry-run](./任意external_samples事前検証dry-run.md) — 任意サンプルを db:seed に渡す前に候補・warning・error を DB 変更なしで確認する手順
