# 標準 seed サンプルと確認用途

`docs-portal` の `db:seed` は、CSV 取り込みの前に標準 showcase サンプルを再生成してから `storage/document_files/external_samples/` を取り込みます。

このページでは、repo 標準で入るサンプル、任意に持ち込む `external_samples`、用途特化の `ai-usecases` サンプルを混同しないための整理と、標準 showcase を使って何を確認できるかをまとめます。

## 位置づけ

| 種類 | 配置 | 役割 |
| --- | --- | --- |
| 標準 showcase サンプル | `storage/document_files/external_samples/seed-showcase/docs-portal-demo/` | Markdown / Mermaid / PDF / Excel / CSV / ZIP / 複数版の代表導線を少ない文書数で確認する |
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
| `sample-archive.zip` | ZIP | ZIP preview、ZIP 内項目 preview、個別 download 導線 |
| `提出済/README.md` | 旧版 Markdown | current と旧版の切り替え、版比較の前提確認 |

`README.md` 自体にも Mermaid ブロック、PlantUML 記法サンプル、添付ファイルリンクが含まれています。1 つの文書で Markdown 本文と添付導線の両方を見たいときは、このページが最短の確認入口です。

PlantUML 記法サンプルは seed showcase の代表コンテンツです。Kroki plugin の mock smoke は `docusaurus/plugins/remark-kroki-diagrams.smoke.test.mjs` が担当し、実 Kroki service なしで変換・生成先・画像 URL の契約を確認します。

## どの確認に使うか

| 観点 | 最初に見るファイル | 補足 |
| --- | --- | --- |
| Markdown 表示 | `README.md` | 見出し、表、コードブロック、リンクをまとめて確認できる |
| Mermaid 導線 | `README.md` または `process.mmd` | Markdown 内の Mermaid と補助ファイルの両方を持つ |
| PDF 導線 | `README.pdf` | プレビューできない環境でもダウンロード導線は確認しやすい |
| Excel 導線 | `README.xlsx` | Office preview や添付導線の確認に使う |
| CSV 導線 | `runbook.csv` | CSV 系プレビューの確認に使う |
| ZIP 導線 | `sample-archive.zip` | ZIP preview、ZIP 内の Markdown / CSV / nested entry preview、個別 download の代表確認に使う |
| 複数版 | `README.md` と `提出済/README.md` | current / 旧版の切り替えや比較前提を確認する |
| 手順書系の実運用寄りコンテンツ | `ai-usecases/AI活用手順ポータル/` | showcase より業務コンテンツ寄りのサンプルを見たい場合に使う |

## 任意 external sample の追加手順

任意サンプルは、標準 showcase とは別の `<sample-set>` 配下に置きます。`db:seed` 前に入力ファイルをそろえ、seed 後は portal 上の Project / Document / DocumentFile と生成 HTML を確認します。

1. `bin/setup_external_sample_data_links` を実行し、`storage/document_files/external_samples` が存在する状態にします。この script は root directory を用意するだけで、サンプルの検証、cleanup、retention 判断は行いません。
2. `storage/document_files/external_samples/<sample-set>/<site-dir>/...` にサンプルを配置します。`site-dir` ごとに 1 Project として取り込まれ、Markdown は 1 ファイルまたは 1 ディレクトリを 1 Document として扱います。
3. 旧版や提出済み snapshot を持たせたい場合は、`提出済`、`提出済み`、`編集正本` などの snapshot directory を `site-dir` 配下に置きます。snapshot directory 以外の current 側からは、これらの directory は除外して読み取られます。
4. `rails db:seed` を実行し、対象 sample set の Project、Document、DocumentVersion、添付 DocumentFile が作られることを確認します。添付ファイルは seed 時に `external_sample_seed_files/...` の storage key へ materialize されます。
5. Docusaurus build が必要な Markdown は、Document 詳細の HTML 表示と添付導線を確認します。PlantUML / D2 など Kroki 前提の記法を含む場合は、Kroki runtime 前提も別途確認してください。

不要になった任意サンプルは、次回 seed の入力から外すために `external_samples` 配下の対象 directory を削除または退避します。ただし、既に取り込まれた DB row、storage file、retention、production data の cleanup 方針はこの手順では決まりません。cleanup や validation command が必要な場合は、seed / storage 運用の別 issue として扱ってください。

標準 showcase は `db:seed` のたびに再生成されます。標準 showcase の文面や添付を変更したい場合は `seed-showcase/docs-portal-demo` を直接編集せず、`db/seeds/support/seed_sample_document_generator.rb` とこの docs の確認用途を合わせて見直します。`ai-usecases` は手順書系の用途特化サンプルですが、取り込みは任意 external sample と同じ一般ルールです。

## 運用メモ

- 標準 showcase サンプルは `db:seed` のたびに再生成されるため、直接編集しても次回 seed で上書きされます。
- `sample-archive.zip` は ZIP preview の代表導線を確認するための小さい deterministic archive です。unsafe path、nested archive、巨大 ZIP、bulk download の境界確認には使いません。
- 任意サンプルを追加したい場合は、README にある一般ルールどおり `storage/document_files/external_samples/<sample-set>/<site-dir>/...` 配下へ配置します。
- PlantUML / D2 を含む Markdown を seed して描画確認したい場合は、Kroki 設定も必要です。runtime 前提と mock smoke の実行入口は [notes/docusaurus-build-runtime](./notes/docusaurus-build-runtime.md) を参照してください。
- Office preview の接続条件を確認したい場合は [Microsoft Graph接続とOffice preview](./Microsoft%20Graph%E6%8E%A5%E7%B6%9A%E3%81%A8Office%20preview.md) を参照してください.
