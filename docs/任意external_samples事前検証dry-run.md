# 任意 external_samples 事前検証 dry-run

任意の `external_samples` を `db:seed` に渡す前に、DB 変更なしで sample set / site / document / version / attachment 候補を確認するための運用メモです。

## 役割

`bin/setup_external_sample_data_links` は `storage/document_files/external_samples` の root directory を用意するだけです。サンプル構造の検証、cleanup、retention 判断、DB seed、標準 showcase 再生成は行いません。

`bin/validate_external_samples` は、既存 seed importer と同じ候補解釈に寄せて `external_samples` を読み取り、取り込み候補と warning / error を表示します。dry-run 専用で、`Project`、`Document`、`DocumentVersion`、`DocumentFile` の保存、CSV seed、標準 showcase 再生成、Docusaurus build は実行しません。

## 使い方

1. `bin/setup_external_sample_data_links` を実行し、root directory を作ります。
2. `storage/document_files/external_samples/<sample-set>/<site-dir>/...` に任意サンプルを配置します。
3. `bin/validate_external_samples` を実行します。
4. warning / error を確認し、必要ならサンプル配置を直します。
5. 問題ないことを確認してから `rails db:seed` を実行します。

JSON で確認したい場合は次のように実行します。

```sh
bin/validate_external_samples --format=json
```

別 root や添付サイズ warning の閾値を変えたい場合は、次の option を使います。

```sh
bin/validate_external_samples --root=storage/document_files/external_samples --max-attachment-mb=20
```

## 出力の読み方

summary には、候補として読めた project 数、document 数、document version 数、attachment 数が出ます。candidate には project code / project name、document title / slug、version label、Markdown entry、site build path、attachment count が出ます。

warning は、seed を止めるとは限らない注意です。代表例は、root 未作成、sample set なし、Markdown 候補なし、添付ファイルが大きい場合です。

error は、`db:seed` 前に直すべき構造です。代表例は、candidate path が source directory の外へ出る symlink、候補ファイル消失、同じ project / slug / version に複数候補が割り当たる場合です。

## 非目標

- `db:seed` の代替
- 標準 showcase の再生成
- CSV seed の実行
- `Document` / `DocumentVersion` / `DocumentFile` の保存
- Docusaurus build の実行
- cleanup、retention、production data 判断
