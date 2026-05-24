# 標準 seed サンプルと確認用途

`docs-portal` の `db:seed` は、CSV 取り込みの前に標準 showcase サンプルを再生成してから `storage/document_files/external_samples/` を取り込みます。

このページでは、repo 標準で入るサンプル、任意に持ち込む `external_samples`、用途特化の `ai-usecases` サンプルを混同しないための整理と、標準 showcase を使って何を確認できるかをまとめます。

## 位置づけ

| 種類 | 配置 | 役割 |
| --- | --- | --- |
| 標準 showcase サンプル | `storage/document_files/external_samples/seed-showcase/docs-portal-demo/` | Markdown / Mermaid / PDF / Excel / CSV / 複数版の代表導線を少ない文書数で確認する |
| 用途特化サンプル | `storage/document_files/external_samples/ai-usecases/AI活用手順ポータル/` | AI 活用手順や判断フローのような、手順書系コンテンツの seed 例として使う |
| 任意の外部サンプル | `storage/document_files/external_samples/<sample-set>/<site-dir>/...` | 利用者や開発者が独自に持ち込む確認用コンテンツ |

標準 showcase サンプルは `db/seeds/support/seed_sample_document_generator.rb` が毎回再生成します。`ai-usecases` や任意サンプルは、この generator とは別に `external_samples` の一般ルールで取り込まれます。

## 標準 showcase の生成内容

標準 showcase は `seed-showcase/docs-portal-demo` を current 版、`提出済/README.md` を旧版として持ちます。

| パス | 種別 | 主な確認用途 |
| --- | --- | --- |
| `README.md` | Markdown | 見出し、表、コードブロック、添付ファイルリンク、文書本文の表示 |
| `runbook.md` | Markdown | 文書ツリー内で複数 Markdown 文書が並ぶ導線 |
| `process.mmd` | Mermaid ファイル | Markdown 以外の補助ファイルが tree や添付として見えるかの確認 |
| `runbook.csv` | CSV | CSV プレビューやダウンロード導線 |
| `README.pdf` | PDF | PDF プレビューまたはダウンロード導線 |
| `README.xlsx` | Excel | Office / Excel 系ファイルの導線 |
| `提出済/README.md` | 旧版 Markdown | current と旧版の切り替え、版比較の前提確認 |

`README.md` 自体にも Mermaid ブロック、PlantUML 記法サンプル、添付ファイルリンクが含まれています。1 つの文書で Markdown 本文と添付導線の両方を見たいときは、このページが最短の確認入口です。

## どの確認に使うか

| 観点 | 最初に見るファイル | 補足 |
| --- | --- | --- |
| Markdown 表示 | `README.md` | 見出し、表、コードブロック、リンクをまとめて確認できる |
| Mermaid 導線 | `README.md` または `process.mmd` | Markdown 内の Mermaid と補助ファイルの両方を持つ |
| PDF 導線 | `README.pdf` | プレビューできない環境でもダウンロード導線は確認しやすい |
| Excel 導線 | `README.xlsx` | Office preview や添付導線の確認に使う |
| CSV 導線 | `runbook.csv` | CSV 系プレビューの確認に使う |
| 複数版 | `README.md` と `提出済/README.md` | current / 旧版の切り替えや比較前提を確認する |
| 手順書系の実運用寄りコンテンツ | `ai-usecases/AI活用手順ポータル/` | showcase より業務コンテンツ寄りのサンプルを見たい場合に使う |

## 運用メモ

- 標準 showcase サンプルは `db:seed` のたびに再生成されるため、直接編集しても次回 seed で上書きされます。
- 任意サンプルを追加したい場合は、README にある一般ルールどおり `storage/document_files/external_samples/<sample-set>/<site-dir>/...` 配下へ配置します。
- PlantUML / D2 を含む Markdown を seed して描画確認したい場合は、Kroki 設定も必要です。runtime 前提は [notes/docusaurus-build-runtime](./notes/docusaurus-build-runtime.md) を参照してください。
- Office preview の接続条件を確認したい場合は [Microsoft Graph接続とOffice preview](./Microsoft%20Graph%E6%8E%A5%E7%B6%9A%E3%81%A8Office%20preview.md) を参照してください.
