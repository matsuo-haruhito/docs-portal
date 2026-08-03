# ZIPインポートdry-run運用 runbook

この文書は issue `#655` に対応する、`docs-portal` の ZIP インポート運用メモです。

## 1. この runbook が扱う画面

admin ナビゲーションでは、`ZIPインポート` から次の 2 段を見ます。

- `ZIPインポート`: `admin/zip_imports/new`
- `ZIPインポートdry-run`: `admin/zip_imports/:id`

使い分けは次です。

- 新しい ZIP を取り込み候補として解析したいときは `ZIPインポート`
- dry-run の結果を見て、取り込み前の最終確認をしたいときは `ZIPインポートdry-run`

## 2. 最初の切り分け順

1. 取り込み先の `案件` が正しいかを確認する
2. 必要なら `版ラベル` と `取り込み後ステータス` を決める
3. `取り込み元リポジトリ/メモ` `取り込み元ブランチ` `取り込み元commit` を、追跡したい範囲だけ入力する
4. ZIP をアップロードして `dry-runを作成` する
5. `ZIPインポートdry-run` で `状態`、集計、TreeView プレビューを確認する
6. 問題がなければ `この内容で取り込む` を実行する

## 3. `ZIPインポート` 画面で決める項目

form では少なくとも次を確認します。

- `案件`: 取り込み先 Project
- `版ラベル`: 任意。空でも作成できるが、後で見返したいときは入力しておく
- `取り込み後ステータス`: current code では `draft` / `published` / `archived`
- `取り込み元リポジトリ/メモ`: 任意のメモ。Git 由来の ZIP なら repository 名の控えに使う
- `取り込み元ブランチ`: 任意
- `取り込み元commit`: 任意
- `ZIPファイル`: 必須

この画面で dry-run 作成に失敗した場合は、同じ画面に戻って alert が出ます。`案件` 未指定、ZIP 未指定、validation error などは、まずこの戻り先で確認します。

## 4. `ZIPインポートdry-run` で最初に見ること

`取り込み概要` card では次を確認します。

- `案件`: どの案件へ入る dry-run か
- `状態`: `analyzed` / `confirmed` / `expired` / `failed`
- `dry-run ID`: 問い合わせや追跡に使う ID
- `合計`: 取り込み候補の総数
- `新規`: 新しく作られる候補数
- `更新`: 既存文書へ version 追加や更新候補になる数
- `警告`: dry-run summary 上の warning 件数

最初の判断基準は次です。

- `analyzed`: まだ実行前。`この内容で取り込む` を押せる状態
- `confirmed`: すでに実行済み
- `failed`: dry-run 自体は保存されているが、内容確認より先に作成処理の失敗要因を疑う
- `expired`: 古い dry-run として再利用しない前提で見直す

current controller では `analyzed` の dry-run だけが実行対象です。`confirmed` 以降は、同じ ID を再実行するより `別のZIPをアップロード` から作り直す前提で見ます。

## 5. TreeView プレビューの見方

`TreeViewプレビュー` は、左が現在、右が取り込み後の見込みです。

- `現在`: 既存の案件文書ツリー
- `取り込み後`: 既存文書に ZIP 内の候補を重ねた見込み
- badge: current code では `create` / `update` / `change`

読み方のコツは次です。

- まず左に無い path が右に増えていれば、新規取り込み候補の可能性が高い
- 同じ path に badge が付いていれば、既存文書への変更候補として見る
- `change` は create / update 以外の差分まとめなので、細かい分類をここで決め打ちしない
- 左右とも空なら、その案件に対して有効な文書候補を作れていない可能性がある

このプレビューは path と title の見え方を確認する補助です。公開範囲、権限、Docusaurus build 成否まではここで確定しません。

## 6. warning と error の見方

current ZIP dry-run 画面では、専用の warning / error 一覧より先に、`取り込み概要` の `警告` 件数と、dry-run 作成時の alert を起点に切り分けます。

- dry-run 作成前後で画面が `ZIPインポート` に戻り alert が出たとき: upload 条件や validation error を先に確認する
- `ZIPインポートdry-run` が作成され、`警告` 件数だけ増えているとき: 実行前に TreeView プレビューと入力値を見直す
- `analyzed` でなければ: warning より先に status を確認し、作り直すかどうかを判断する

現時点では ZIP import の詳細仕様を [importと変更系dry-run](./specs/importと変更系dry-run.md) が正本として持っています。この runbook では、画面から見える warning count と実行前確認順だけに留めます。

## 7. 実行前に戻る判断が必要なとき

次のようなときは、すぐ取り込まずに前段へ戻ります。

- `案件` を選び間違えていた
- `取り込み後ステータス` を `draft` 以外にした理由が曖昧なままになっている
- TreeView プレビューの path や title が想定より大きくずれている
- `警告` 件数が増えているのに、何が増減するのか説明できない
- すでに `confirmed` で、同じ ZIP を再確認したい

戻り先は次です。

- 入力のやり直し: `別のZIPをアップロード`
- import 仕様の確認: [importと変更系dry-run](./specs/importと変更系dry-run.md)
- 文書公開モデルや version status の確認: [アプリケーション仕様](./アプリケーション仕様.md)

## 8. current support の境界

- この runbook は `ImportDryRun(import_mode=zip)` の current admin 画面だけを扱います
- Git 連携 import や外部フォルダ同期の確認順は別 runbook を正本にします
- warning / error の内部 JSON schema や importer 実装詳細は、この文書では再定義しません
- ZIP 取り込み後の公開判定、権限制御、Docusaurus build の成否は別仕様・別運用 docs を参照します

## 9. 関連文書

- [importと変更系dry-run](./specs/importと変更系dry-run.md)
- [ZIPインポートdry-run 履歴保存境界メモ](./ZIPインポートdry-run履歴保存境界メモ.md)
- [アプリケーション仕様](./アプリケーション仕様.md)
- [Git連携設定と同期失敗確認 runbook](./Git連携設定と同期失敗確認runbook.md)
- [外部フォルダ同期dry-run・apply運用 runbook](./外部フォルダ同期dry-run・apply運用runbook.md)
- [README](../README.md)
- [docs/README](./README.md)
