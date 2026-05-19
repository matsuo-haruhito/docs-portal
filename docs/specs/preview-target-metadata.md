# Preview target metadata

`preview_targets` metadata は、文書版に含まれる添付・元ファイルのうち、プレビューで優先表示する本文、通常添付、補助的に隠すファイル、調査用ファイル、グループ化したファイルを明示するための仕様です。

## 目的

- Markdown / HTML プレビューで、最初に見るべきファイルを明確にする
- ZIP や複数ファイル upload 由来の添付を、利用者向けに整理して表示する
- hidden / debug のような低優先度ファイルを通常一覧から分け、必要な場合だけ確認できるようにする
- quality check で metadata の不整合を warning として検出する

## metadata source の優先順位

文書版の `document_files` を `sort_order, id` 順に見て、次の順で source file を決定します。

1. 明示 metadata file
2. Markdown front matter fallback

明示 metadata file は、ファイル名の basename が次のいずれかに一致するものです。

1. `.docs-portal-preview.yml`
2. `.docs-portal-preview.yaml`
3. `.preview-targets.yml`
4. `.preview-targets.yaml`
5. `preview-targets.yml`
6. `preview-targets.yaml`
7. `preview_targets.yml`
8. `preview_targets.yaml`

明示 metadata file がない場合、拡張子が `.md` または `.markdown` の最初のファイルを Markdown front matter fallback として使います。

## YAML structure

明示 metadata file の場合は通常の YAML として、Markdown の場合は front matter 内の YAML として読みます。

```yaml
preview_targets:
  primary: README.md
  attachments:
    - attachments/spec.pdf
  hidden:
    - hidden/private.pdf
  debug:
    - debug/raw.json
  groups:
    diagrams:
      - diagrams/flow.puml
```

`preview_targets` の下では、次の key のみをサポートします。

| key | 目的 | 表示上の扱い |
| --- | --- | --- |
| `primary` | プレビュー本文・入口として優先したいファイル | 通常表示ファイル |
| `attachments` | 利用者が通常確認する添付ファイル | 通常表示ファイル |
| `hidden` | 通常確認から外したい内部資料・補助ファイル | 折りたたみの hidden files |
| `debug` | レンダリング確認や調査用のファイル | 折りたたみの debug files |
| `groups` | 図、参考資料、データなど任意のまとまり | group ごとの専用セクション |

## path normalization

path は文字列として扱い、次の正規化を行います。

- 前後の空白を取り除く
- `\\` を `/` に寄せる
- 先頭 `/` を取り除き、文書版内の相対パスとして扱う
- `.` や `..`、`../` で文書版外へ出る path は metadata から除外する

除外された unsafe path は `unsafe_relative_path` warning として quality check に表示します。

## supported shapes

`primary`, `attachments`, `hidden`, `debug` は、文字列・配列・ネスト配列・Hash の values を path list に正規化します。

```yaml
preview_targets:
  primary: README.md
  attachments:
    - attachments/spec.pdf
    - [attachments/appendix.pdf]
  debug:
    raw: debug/raw.json
```

`groups` は Hash を推奨します。Hash の key が group 名になります。

```yaml
preview_targets:
  groups:
    diagrams:
      - diagrams/flow.puml
    references:
      - references/api.md
```

`groups` が配列の場合は `group_1`, `group_2` のように自動命名します。

## warning conditions

quality check では、metadata source と warning を `preview_target_metadata` として表示します。

| code | 条件 | 補足 |
| --- | --- | --- |
| `unknown_key` | `preview_targets` 配下に未対応 key がある | 未対応 key は無視する |
| `missing_path` | 指定 path が文書版の `document_files` に存在しない | 正規化後の path で照合する |
| `duplicate_path` | 同じ path が複数 target に指定されている | role や group が曖昧になるため warning |
| `invalid_yaml` | YAML として parse できない | metadata は空扱い |
| `unsafe_relative_path` | `.` / `..` / `../...` など文書版外へ出る path | metadata から除外する |

## version page display

文書版詳細の「添付・元ファイル」では、metadata がある場合に次のように表示を分けます。

1. `Preview target metadata` summary card
2. `通常表示ファイル`
   - `primary`
   - `attachment`
   - `normal`
3. `group: <group name> <count>件`
4. `hidden files <count>件`
5. `debug files <count>件`
6. `その他のファイル`

各ファイル行には、metadata に基づく role badge と group / hidden / debug badge を付けます。download 権限や download link の判定は既存の `DocumentFile#downloadable_by?` に従い、metadata によって権限を変更しません。

## current non-goals

- hidden / debug を ZIP export から除外すること
- metadata source file 自体を upload 対象から自動的に隠すこと
- metadata によって権限判定を変えること
- path history / redirect を扱うこと

これらは別仕様として扱います。
