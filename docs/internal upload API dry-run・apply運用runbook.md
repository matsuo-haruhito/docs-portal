# internal upload API dry-run・apply運用 runbook

この文書は issue `#739` に対応する、`docs-portal` の internal upload API 運用メモです。

## 1. この runbook が扱う入口

この runbook では、同じ importer pipeline を使いながら入口が分かれている次の 3 系統を扱います。

- `POST /api/internal/artifact_imports`
- `POST /api/internal/zip_uploads`
- `POST /api/internal/file_uploads`

最初の見分け方は次です。

| 入口 | 誰が使うか | dry-run を作る request | apply を行う request |
| --- | --- | --- | --- |
| `artifact_imports` | GitHub Actions や build pipeline | `validate_only=true` を付けて `artifact_root` と `manifest_path` を送る | `validate_only` を付けずに `artifact_root` と `manifest_path` を送る。dry-run と対応づける場合だけ `git_push` / `analyzed` の `import_dry_run_id` を付ける |
| `zip_uploads` | 管理者が ZIP 一括アップロードで取り込むとき | `validate_only=true` を付けて `zip_file` と `project_code` を送る | `import_dry_run_id` を付けて同じ `zip_uploads` へ送る |
| `file_uploads` | 同期クライアントや単体ファイルの手動取り込み | `file` を付けて送る。`validate_only=true` は省略できる | `import_dry_run_id` を付けて同じ `file_uploads` へ送る。管理画面では `admin/file_upload_dry_runs` で一覧確認し、`admin/file_upload_dry_runs/:public_id` で詳細確認・実行できる |

`zip_uploads` と `file_uploads` は「アップロード request で dry-run を作り、保存済み dry-run を同じ API へ戻して apply する」流れです。
`artifact_imports` だけは、生成済み artifact と manifest を直接 apply できる入口として残っています。

## 2. 最初に確認する順番

1. 取り込み元が build artifact なのか、ZIP なのか、単体ファイルなのかを決める
2. dry-run を作る request なのか、保存済み dry-run を apply する request なのかを決める
3. `validate_only`、`file`、`zip_file`、`import_dry_run_id` のどれが今回の切り分け軸かを見る
4. dry-run を使う flow なら、response の `dry_run_id`、`status`、`expires_at` を控える
5. apply 前に、dry-run の `status` が `analyzed` のままかを確認する
6. `artifact_imports` へ `import_dry_run_id` を渡す場合は、その dry-run が `git_push` mode で作られたものかを確認する

mode を取り違えると、`zip_uploads` / `file_uploads` では apply できません。`artifact_imports` でも、`zip` / `manual_upload` の dry-run ID は確認 ID として使えません。まず「どの API で dry-run を作ったか」を固定してから見直します。

## 3. `artifact_imports` の見方

`artifact_imports` は、すでに展開済みの artifact と `publish.json` を受け取る入口です。

`artifact_root` と `manifest_path` は `storage/imports/` 配下の artifact を指す値として扱います。current importer は、解決後の `manifest_path` が解決後の `artifact_root` 配下にあることを確認します。`../` などで artifact root の外へ逃げる manifest は forbidden として読み、error response に raw path が出ていないかも合わせて確認します。

### dry-run を作る request

- `validate_only=true`
- `artifact_root`
- `manifest_path`

current controller は、この request で `ImportManifestDryRun` を走らせ、`dry_run_id`、`status`、`expires_at` を返します。
保存される dry-run は `import_mode: git_push`、`status: analyzed` です。`expires_at` は response key として返りますが、保存期間や retention policy をこの runbook で新しく決めているわけではありません。
`project_code` は request では受けず、manifest 内の project 群から `ImportDryRun.project` を推定します。

### apply を行う request

- `artifact_root`
- `manifest_path`
- 必要なら `import_dry_run_id`

current code では `import_dry_run_id` がなくても apply 自体はできます。
ただし、dry-run を経由して apply する運用では、`import_dry_run_id` が `git_push` かつ `analyzed` の dry-run を指していることと、manifest の `source_commit_hash` が dry-run 保存時と食い違っていないことを確認します。
`zip_uploads` や `file_uploads` で作った dry-run ID を `artifact_imports` の確認 IDとして流用することはできません。

`import_dry_run_id` 付き apply が成功すると、対象 dry-run は `confirmed` になり、import log には `dry_run=<dry_run_id>` が残ります。commit mismatch や mode mismatch で失敗した場合、dry-run は `analyzed` のままなので、manifest や ID を見直してから再実行します。

PR / incident evidence で dry-run なし直接 apply を確認するときは、PublishJob log の `dry_run=not_provided direct_artifact_apply=true` を補助 cue として読みます。これは direct apply が current support として動いたことを示す記録であり、dry-run 確認済み、strict 化、direct apply 廃止、または ZIP / file upload flow の evidence ではありません。dry-run 付き apply の `dry_run=<dry_run_id>` と混ぜずに分けて残します。

### この入口で困ったとき

- `DOC_IMPORT_ACTOR_EMAIL is not configured` や `Import actor not found` が返る: import actor 設定を先に確認する
- `import_dry_run_id must reference an analyzed git_push dry-run` が返る: `zip` / `manual_upload` の dry-run ID を artifact apply に流用していないか、または対象 dry-run がすでに `confirmed` / `expired` / `failed` になっていないかを確認する
- `source_commit_hash does not match the confirmed dry-run` が返る: dry-run 作成後に別 commit の manifest を apply しようとしている
- dry-run を使うつもりで `import_dry_run_id` を付けていない: current code では apply できるが、運用上は dry-run との対応づけが薄くなる。PublishJob log の `dry_run=not_provided direct_artifact_apply=true` は direct apply の補助 cue としてだけ読み、dry-run confirmed の証跡として扱わない

## 4. `zip_uploads` の見方

`zip_uploads` は、アップロードされた ZIP を staging して dry-run を作る入口です。

### dry-run を作る request

- `validate_only=true`
- `zip_file`
- `project_code`
- 必要に応じて `source_repo`、`source_branch`、`source_commit_hash`、`version_label`、`status`

current controller は、ZIP 展開後の manifest と `zip_import_preview` を dry-run に保存します。
response でも `dry_run_id`、`status`、`expires_at`、`zip_import_preview` を返します。

### apply を行う request

- `import_dry_run_id`

apply request では `zip_file` を送りません。controller は保存済み dry-run の `artifact_root` と `manifest_path` を使って importer を呼びます。
`import_dry_run_id` は `status: analyzed` かつ `import_mode: zip` の dry-run である必要があります。

### この入口で困ったとき

- `import_dry_run_id is required for ZIP upload execution`: apply request に dry-run ID が付いていない
- `ZIP dry-run artifact is missing`: 保存済み dry-run に `artifact_root` / `manifest_path` が無い
- すでに `confirmed` や `expired` の dry-run を使っている: 同じ ID を再利用せず、ZIP をアップロードし直す

`zip_uploads` の日常運用で画面を見ながら確認するときは、[ZIPインポートdry-run運用 runbook](./ZIP%E3%82%A4%E3%83%B3%E3%83%9D%E3%83%BC%E3%83%88dry-run%E9%81%8B%E7%94%A8runbook.md) を正本にします。

## 5. `file_uploads` の見方

`file_uploads` は、単体ファイルを受けてサーバー側で一時 ZIP 化し、ZIP upload と同じ importer pipeline へ流す入口です。

### dry-run を作る request

- `file`
- `project_code`
- 必要に応じて `relative_path`、`original_filename`、`source_path`、`source_name`、`content_hash`、`source_commit_hash`、`version_label`、`status`

この入口では `file` がある request が dry-run 作成として扱われます。
そのため `validate_only=true` は省略できます。付けても同じく dry-run 作成です。
response では `file_upload_preview` が返り、`source_name`、`relative_path`、`source_path`、`content_hash`、採用後の `source_commit_hash`、`version_label` を確認できます。

### apply を行う request

- `import_dry_run_id`

apply request では `file` を送りません。`zip_uploads` と同じく、保存済み dry-run に入っている `artifact_root` と `manifest_path` を使って importer を呼びます。
`import_dry_run_id` は `status: analyzed` かつ `import_mode: manual_upload` の dry-run である必要があります。

### 管理画面で dry-run を後から探す

`file_uploads` で作った dry-run は、管理画面の `admin/file_upload_dry_runs` 一覧から後追い確認できます。controller は `import_mode: manual_upload` の dry-run だけを一覧するため、ZIP dry-run や artifact import dry-run はこの一覧に表示されません。

一覧では次の条件で絞り込めます。

- `dry-run ID`: API response の `dry_run_id` と一致する public ID を完全一致で探す。画面では placeholder の `公開ID (例: idry...)` と `dry-run の公開IDで完全一致検索します。` の補助文を目印にする
- `同期元名・取り込み先path・content hash`: `source_name`、取り込み先 `relative_path`、`content_hash` の表示中 safe metadata を部分一致で探す。placeholder は `同期元名・relative path・content hash` です。クライアント側の raw `source_path` は検索対象外です
- `案件`: 案件コード・案件名で bounded remote search し、選択した案件で絞り込む。選択済み案件は候補上限外でも復元され、存在しない `project_id` は filter 未適用として扱います
- `状態`: `analyzed`、`confirmed`、`expired`、`failed` などの状態で絞り込む

一覧列では、作成日時、`dry-run ID`、案件、状態、同期元名、取り込み先 `relative_path`、`content_hash`、詳細 link を確認します。ここで表示する `source_name` / `relative_path` / `content_hash` は照合入口です。クライアント側の raw `source_path` は一覧には表示せず、詳細画面でも raw 値ではなく「relative path と content hash で照合する」方針を表示します。

案件 filter の候補は最大 20 件です。大量案件で見つからない場合は、案件コードや案件名の特徴的な断片で絞り込みます。選択済み案件が候補上限外にあっても selected project endpoint で label が復元されるため、filter form 上の案件名 / 案件コードを見て現在条件を読み返せます。

0 件になったときは、filter なしなら manual_upload dry-run がまだ作られていない状態です。filter ありなら、控えている `dry_run_id`、同期元名・取り込み先path・content hash の検索語、案件、状態のいずれかが current dry-run と合っているかを見直し、必要なら `絞り込み解除` で一覧に戻ります。クライアント側の raw `source_path` 検索、ZIP dry-run との横断検索、artifact import dry-run との統合一覧は current support ではありません。

### 管理画面で dry-run を確認・実行する

`file_uploads` で作った dry-run は、管理画面の `admin/file_upload_dry_runs/:public_id` でも確認できます。controller は `import_mode: manual_upload` の dry-run だけを読み込むため、ZIP dry-run や artifact import dry-run の ID をここへ持ち込んでも対象になりません。

画面では次を確認します。

- `案件`、`状態`、`dry-run ID`
- `source_name`、`relative_path`
- raw `source_path` を画面に表示しないことと、照合には `relative_path` / `content_hash` を使うこと
- `file_size`、`content_hash`、`source_commit_hash`、`version_label`
- summary の `合計` / `新規` / `更新` / `警告`
- warning / error
- TreeView プレビューの `現在` と `取り込み後`

`状態` が `analyzed` の dry-run では、画面の `この内容で取り込む` から apply できます。実行後は dry-run が `confirmed` になり、同じ dry-run を再実行するのではなく、必要ならファイルをアップロードし直して新しい dry-run を作ります。

API response と画面を照合するときは、まず `dry_run_id` と画面の `dry-run ID` が一致することを確認します。次に `relative_path`、`content_hash`、`source_commit_hash`、warning / error、TreeView の差分を見ます。`source_path` は取り込み先を決める値ではなく、同期元やクライアント側の参考情報です。current UI は raw `source_path` を表示しません。private path や端末固有の path をどの範囲で保存・表示・検索するかの判断が必要になった場合は、表示範囲の判断を #1613 に戻します。

### `relative_path` と `source_path` の違い

- `relative_path`: 取り込み対象を識別するための安全な相対 path
- `source_path`: クライアント PC 上のフルパスなど、参考情報として残す path

current code は `relative_path` の先頭 `/`、`../`、Windows drive path を拒否します。
`source_path` は参考情報であり、保存先決定には使いません。

### `content_hash` と `source_commit_hash` の見方

- `content_hash` はアップロード元ファイル実体の SHA-256 と照合する
- `content_hash` は `sha256:` 接頭辞付き、または 64 桁 hex で送る。接頭辞付きで送っても、response の `file_upload_preview.content_hash` は 64 桁 hex で返る
- `source_commit_hash` が request にあれば、それを採用値として優先する
- どちらも無ければ、アップロード元ファイル実体の SHA-256 を `source_commit_hash` として採用する

### この入口で困ったとき

- `file` を付けたつもりで apply まで進めてしまった: `file_uploads` では `file` 付き request は dry-run 作成側になる
- `content_hash must be a SHA-256 hex digest`: `content_hash` が `sha256:` 接頭辞付き 64 桁 hex、または 64 桁 hex ではない
- `content_hash does not match uploaded file`: クライアントが送ったハッシュと実体が一致していない
- `relative_path is invalid`: `../`、先頭 `/`、Windows drive path など unsafe path が含まれている
- 管理画面で dry-run が一覧に出ない: `admin/file_upload_dry_runs` は `import_mode: manual_upload` の dry-run だけを見る。ZIP dry-run は [ZIPインポートdry-run運用 runbook](./ZIP%E3%82%A4%E3%83%B3%E3%83%9D%E3%83%BC%E3%83%88dry-run%E9%81%8B%E7%94%A8runbook.md) 側で確認し、artifact import dry-run は API response と import log を起点に確認する
- 管理画面で dry-run が開けない: `admin/file_upload_dry_runs/:public_id` は `import_mode: manual_upload` の dry-run だけを見る。URL の ID、案件、状態を一覧で確認し直す
- `実行済み、または実行できないdry-runです。`: 管理画面から apply しようとした dry-run が `analyzed` ではない
- `file upload dry-run artifact is missing`: 保存済み dry-run に `artifact_root` / `manifest_path` が無い

## 6. `validate_only` と `import_dry_run_id` の読み分け

切り分けの要点は次です。

- `validate_only=true`
  - `artifact_imports`: dry-run を保存する明示フラグ。response の `dry_run_id` は `git_push` / `analyzed` の dry-run を指す
  - `zip_uploads`: dry-run を保存する明示フラグ
  - `file_uploads`: `file` があれば省略できる。付けても dry-run 作成の意味は同じ
- `import_dry_run_id`
  - `zip_uploads` / `file_uploads`: apply に必須
  - `artifact_imports`: current code では任意だが、dry-run と apply の対応づけに使える。付ける場合は `git_push` / `analyzed` の dry-run ID だけが有効

同じ `import_dry_run_id` でも API をまたいで流用はできません。
`zip_uploads` で作った dry-run は `zip_uploads` へ、`file_uploads` で作った dry-run は `file_uploads` または `admin/file_upload_dry_runs` へ戻します。`artifact_imports` で作った dry-run は `artifact_imports` の apply 確認 ID としてだけ使い、ZIP / manual upload の管理画面 flow へ持ち込みません。

## 7. 再作成した方が早いとき

次のようなときは、同じ dry-run ID にこだわらず作り直した方が早いです。

- dry-run の `status` が `confirmed`、`expired`、`failed` になっている
- `artifact_root` や `manifest_path` が保存されていない
- `source_commit_hash` が変わった manifest を apply しようとしている
- API と dry-run mode が合っていない
- `relative_path` や `content_hash` の入力を直したい
- ZIP や単体ファイルの中身自体を差し替えた

## 8. current support の境界

- この runbook は current controller behavior と request parameter の見分け方を扱います
- importer 本体の仕様、preview JSON の詳細 schema、version 管理の設計は [importと変更系dry-run](./specs/import%E3%81%A8%E5%A4%89%E6%9B%B4%E7%B3%BBdry-run.md) と [Internal upload API naming](./internal_upload_api_naming.md) を正本にします
- admin UI で ZIP dry-run を確認する画面運用は [ZIPインポートdry-run運用 runbook](./ZIP%E3%82%A4%E3%83%B3%E3%83%9D%E3%83%BC%E3%83%88dry-run%E9%81%8B%E7%94%A8runbook.md) を正本にします
- admin UI で manual upload dry-run を確認する場合、この runbook は `index` / `show` / `update` の current behavior と API response の照合順を扱います。`dry-run ID` の完全一致検索、`source_name` / `relative_path` / `content_hash` の safe metadata 検索、案件 remote search は一覧で使える current support です。raw `source_path` の表示・検索範囲、ZIP / artifact import dry-run との統合一覧、全 admin 画面共通 project search 抽象化は別 issue の判断に戻します
- build artifact を生成する CI 側の確認順は [build-docs workflow確認runbook](./build-docs%20workflow%E7%A2%BA%E8%AA%8Drunbook.md) を正本にします
- `artifact_imports` の `expires_at` は response key として確認できますが、CI artifact replay、dry-run 保存期間、retention policy はこの runbook で新規確定しません

## 9. 関連文書

- [importと変更系dry-run](./specs/import%E3%81%A8%E5%A4%89%E6%9B%B4%E7%B3%BBdry-run.md)
- [Internal upload API naming](./internal_upload_api_naming.md)
- [ZIPインポートdry-run運用 runbook](./ZIP%E3%82%A4%E3%83%B3%E3%83%9D%E3%83%BC%E3%83%88dry-run%E9%81%8B%E7%94%A8runbook.md)
- [build-docs workflow確認runbook](./build-docs%20workflow%E7%A2%BA%E8%AA%8Drunbook.md)
- [README](../README.md)
- [docs/README](./README.md)
