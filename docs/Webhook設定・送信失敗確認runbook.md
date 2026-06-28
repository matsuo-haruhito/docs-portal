# Webhook設定・送信失敗確認runbook

## 目的

`Webhook` 管理画面で外部通知の送信先を登録し、送信履歴から失敗原因の切り分けと手動再送を始めるための runbook です。payload や署名ヘッダーの設計方針は [Webhook・外部API連携方針](./Webhook・外部API連携方針.md) を正本にし、この runbook では日常運用で見る画面と確認順に絞ります。

## 入口

- internal admin で `admin/webhook_endpoints` の `Webhook` 画面を開きます。
- 画面には `新規登録`、`Webhook設定`、`最近の送信履歴` が並びます。
- `Webhook設定` と `最近の送信履歴` には表示設定があります。失敗調査では送信履歴側の `ステータス`、`HTTP`、`エラー`、`操作` を残しておくと、filter 後の詳細確認と再送可否を読み違えにくくなります。
- `Webhook設定` の設定一覧は、`設定検索`、`イベント`、`状態`、`表示件数` で絞り込めます。`設定検索` は名称 / 送信先URLの部分一致、`イベント` は `WebhookEndpoint::EVENT_TYPES`、`状態` は `すべて` / `有効` / `停止`、`表示件数` は 25 件または 50 件として読みます。
- `Webhook設定` の filter は設定一覧だけに適用されます。最近の送信履歴、送信履歴検索、再送対象、Webhook payload / signature の扱いは変更しません。
- `Webhook設定` の表示範囲は `Webhook設定 N件中M件を表示しています` として出ます。ページが複数ある場合は `前へ` / `次へ` が現在の設定検索・イベント・状態・表示件数を維持します。
- 設定が 0 件の場合は `まだWebhook設定は登録されていません` と読み、filter 後に 0 件の場合は `条件に一致するWebhook設定はありません` と読みます。後者は登録済み endpoint が存在しないという意味ではなく、現在の名称 / URL、イベント、状態条件に一致しない状態です。
- filter 後に 0 件で条件が適用中の場合は、empty state 近くの `Webhook設定の条件をリセット` から Webhook 設定一覧の条件だけを解除できます。この link は最近の送信履歴の `delivery_status` を維持するため、送信履歴側の表示や再送対象は変わりません。初期 0 件状態では解除対象の Webhook 設定条件がないため、この section-local reset は表示されません。
- unsupported な event / active filter、負の page、不正または過大な表示件数は安全に丸められます。URL や任意の戻り先を設定一覧 filter として採用するものではありません。
- `Webhook設定` の `状態` 列では、有効 / 停止の badge と、停止中 endpoint に出る `通常送信・手動再送の対象外` の cue を確認します。停止中 endpoint は通常送信にも失敗 delivery の手動再送にも使われません。
- `Webhook設定` の `削除` は Webhook 設定そのものの destructive action です。confirm では名称、送信先URL、イベント、状態を確認し、送信履歴の詳細確認、1 件再送、表示中のまとめて再送とは別操作として扱います。送信先URLは一覧と同じ表示用 URL で、query は `?...` に畳まれるため、query token や raw parameter を確認する場所ではありません。
- 停止中 endpoint の `削除` も destructive action です。`通常送信・手動再送の対象外` は以後の送信や再送に使われない cue であり、設定削除、過去の Webhook delivery、送信履歴検索、payload / signature 仕様を変更する意味ではありません。
- 送信履歴は `WebhookDelivery.recent.limit(50)` の範囲で、選択した表示条件ごとに最大 50 件を新しい順に確認します。
- 画面には `表示範囲: ...  N件中M件を表示しています` が出るため、status filter 後の総件数と表示件数を分けて確認します。
- 送信履歴は `すべて` / `送信待ち` / `成功` / `失敗` で表示を絞り込めます。
- 50 件外の履歴や、特定 endpoint / event type / status / HTTP status / error message 断片 / 作成日の履歴を探す場合は `送信履歴検索へ` から `admin/webhook_deliveries` を開きます。
- 送信履歴検索は最大 100 件までの read-only 検索一覧です。検索結果全体への bulk retry はありません。
- 送信履歴検索の `Webhook設定` filter は設定名 / 送信先URLの remote search で候補を探し、候補は最大 20 件まで表示されます。選択済み endpoint は候補上限外でも form と戻り先に復元されます。
- 送信履歴の `詳細` と行ごとの `再送` は、現在の status filter または送信履歴検索の条件を安全な戻り先として引き継ぎます。`失敗` 表示や検索一覧から詳細へ入った場合、戻り先と 1 件再送後の戻り先は元の一覧です。
- 不正な戻り先 filter や任意 URL は引き継がず、通常の Webhook 一覧へ戻します。検索一覧の戻り先は `endpoint`、`event_type`、`status`、`response_status`、`error_q`、`created_from`、`created_to` の許可済み条件だけを組み立てます。
- `失敗` 表示中のまとめて再送は、表示中の最大 50 件のうち failed かつ endpoint が有効な delivery だけを対象にします。送信履歴検索の 100 件一覧は bulk retry 対象ではありません。

## 新規登録・編集で見る項目

- `名称`: 送信先を識別する運用名です。
- `送信先URL`: `http` / `https` の URL が必須です。外部送信では HTTPS を標準にしてください。
- `署名シークレット`: 入力すると送信時に `X-Docs-Portal-Signature-256: sha256=<hex digest>` が付与されます。受信側で request body の HMAC-SHA256 検証に使います。
  - 既存 endpoint の編集画面では、保存済み secret の raw value は再表示されません。secret がある場合は `設定済み（変更する場合だけ入力）`、ない場合は `未設定` の状態表示として読みます。
  - secret を変更したい場合だけ新しい値を入力します。既存 endpoint の編集で空欄のまま保存した場合は、既存 secret を維持します。
  - この画面は secret の削除、rotation 手順、受信先への配布 workflow までは定義しません。削除や入れ替え運用が必要な場合は、受信先の検証設定と合わせて別途確認してください。
- `有効`: off の endpoint は `WebhookEndpoint.subscribed_to` の対象外になり、送信されません。失敗 delivery の手動再送も、endpoint が停止中なら実行できません。
- `通知対象イベント`: endpoint ごとに購読する event type を選びます。保存時に未対応値は validation error になります。

current `WebhookEndpoint::EVENT_TYPES` は次の 7 種類です。

- `document_updated`
- `document_published`
- `import_completed`
- `import_failed`
- `review_approved`
- `qa_posted`
- `qa_answered`

## 送信履歴で見る項目

`最近の送信履歴` では、外部通知の成否を endpoint と event type 単位で確認します。

- `作成日時`: delivery record が作成された時刻です。
- `設定`: 対象の Webhook 設定名です。
- `イベント`: delivery の `event_type` です。
- `ステータス`: `送信待ち` / `成功` / `失敗` を表示します。
- `HTTP`: 受信先から返った HTTP status です。通信例外など response がない失敗では空になります。
- `エラー`: 失敗原因を短く読むための preview です。token-like value、authorization 断片、private-looking path などは一覧上で raw 表示せず、長い message も調査入口として読める範囲に短縮されます。HTTP non-2xx の場合は `HTTP` と detail の保存済み response body を手掛かりにします。
- `操作`: `詳細` から delivery の response body / sent_at / target URL などを確認できます。failed かつ endpoint が有効な delivery には一覧行の `再送` ボタンも表示されます。詳細画面から 1 件だけ再送する場合は `この履歴を1件再送` と表示され、どちらも現在の Webhook 設定で対象 delivery を手動再送する操作です。それ以外は `再送不可` と表示されます。

Webhook 一覧トップの `最近の送信履歴` は、直近 50 件の中で失敗有無、HTTP status、短い error preview、再送可否を素早く確認する入口です。raw error 全文、secret-like value、private-looking path を一覧で直接読む場所ではありません。詳しい調査が必要な場合は `詳細` に進み、50 件外や条件を絞った探索が必要な場合は `送信履歴検索へ` を使います。

送信履歴の表示設定を絞る場合も、状態確認では `ステータス` と `操作`、失敗調査では `HTTP` と `エラー` を残してください。`詳細` へ入ったあとの戻り先は status filter または送信履歴検索の許可済み条件だけを保持するため、表示設定で列を隠しても delivery の詳細情報や再送条件そのものは変わりません。

`WebhookDelivery` には request body、response body、error message、sent_at も保存されます。detail 画面の `失敗調査` では、送信先 URL は `WebhookDeliveryTargetUrlDisplay` により scheme / host / path と必要な port だけを残し、query は `?...` に畳んで読みます。error message と response body は `WebhookDeliveryDiagnosticPreview` の短縮 preview で、token-like value、authorization 断片、private-looking path、長大本文を raw 表示しません。request body は `WebhookRequestBodyPreview` のマスク済み preview として別に読みます。これらはいずれも表示専用の調査入口であり、保存値、送信 payload、署名、再送処理を変更するものではありません。

## 送信履歴検索の使い分け

`admin/webhook_deliveries` の送信履歴検索は、最近 50 件の一覧だけでは見つけにくい delivery を探すための補助入口です。

使える条件:

- `Webhook設定`: endpoint 単位で絞り込む。設定名 / 送信先URLの断片で remote search でき、候補は最大 20 件まで表示されます。候補に出ない場合は検索語を具体化し、URL や戻り導線で既に選択済みの endpoint は候補上限外でも selected option として復元されます。
- `イベント`: `WebhookEndpoint::EVENT_TYPES` の event type で絞り込む
- `ステータス`: `送信待ち` / `成功` / `失敗` で絞り込む
- `HTTP status`: `100` から `599` までの HTTP status 完全一致で絞り込む。不正値は検索条件として採用しません。
- `エラー断片`: 保存済み `error_message` に対する部分一致検索で絞り込む。前後空白を除いた最大 100 文字までが検索条件として採用され、空白だけの入力は条件になりません。raw error を追加表示するための条件ではありません。
- `作成日From` / `作成日To`: delivery record の `created_at` 日付範囲で絞り込む。不正な日付は検索条件として採用せず、画面に warning を表示します。

読み方:

- 検索結果は `created_at desc, id desc` の新しい順で最大 100 件まで表示します。
- 結果がある場合だけ `表示範囲: N件中A-B件を新しい順で表示しています` が表示されます。0 件時は範囲 summary ではなく、下の empty state copy を主表示として読みます。
- filter ありで 0 件の場合は、`条件に一致するWebhook送信履歴はありません。Webhook設定、イベント、ステータス、HTTP status、エラー断片、作成日の範囲を見直してください。` と表示されます。Webhook が未送信という断定ではなく、現在の検索条件に一致しない状態として読みます。
- filter なしで 0 件の場合は、`まだWebhook送信履歴はありません。` と表示されます。送信履歴そのものがまだ作られていない初期状態として読み、条件見直しではなく endpoint 設定や送信トリガーの有無を先に確認します。
- 100 件を超える場合は、Webhook設定、イベント、ステータス、HTTP status、エラー断片、作成日を足して範囲を狭めます。無制限一覧や任意の表示件数指定は current support ではありません。
- `Webhook設定` filter で選んだ endpoint は page 移動、詳細への遷移、1 件再送後の戻り先にも引き継がれます。設定名が似ている場合は候補 label の送信先URLも見て選びます。
- `エラー断片` に長い文字列や前後空白を入れた場合、検索・詳細戻り先・再送後の戻り先では、前後空白を除いた最大 100 文字の `error_q` として扱います。空白だけの場合は error message 条件を外して読みます。
- `作成日From` / `作成日To` に日付として解釈できない値がある場合、その条件だけが適用されず、`作成日Fromの値が日付として解釈できないため、この条件は適用していません。` または `作成日Toの値が日付として解釈できないため、この条件は適用していません。` と表示されます。valid な endpoint、event type、status、HTTP status、error message 断片や、もう一方の valid な作成日条件はそのまま適用されます。
- 検索結果の `エラー` 列も、Webhook 一覧トップと同じく短い preview です。検索条件の `エラー断片` は保存済み `error_message` を絞り込むための入力であり、一覧に raw error 全文を展開する指定ではありません。
- 検索結果から `詳細` に入った場合、`送信履歴検索へ戻る` と 1 件再送後の戻り先は元の検索条件です。
- 送信履歴検索には bulk retry を置きません。まとめて再送は従来どおり `Webhook` 画面の `失敗` 表示中、最近 50 件のうち再送可能な delivery に限定します。
- payload edit、payload replay、自動 retry、retention policy 判断は扱いません。

## 失敗時の確認順

1. `Webhook設定` で endpoint が `有効` になっているか、対象 event type が選ばれているかを確認します。
2. `送信履歴` を `失敗` に絞り込み、表示範囲の総件数と表示件数を確認します。50 件外まで調べる必要がある場合は、`送信履歴検索へ` から endpoint / event type / status / HTTP status / error message 断片 / 作成日で探します。`Webhook設定` filter では設定名 / 送信先URLの断片から endpoint を検索できます。`エラー断片` は最大 100 文字までの保存済み `error_message` 検索条件として使います。作成日 From / To の warning が出ている場合は、その日付条件だけが外れているため、他の filter が意図どおりかも合わせて確認します。
3. 失敗行の `詳細` を開きます。`Webhook一覧へ戻る` または `送信履歴検索へ戻る` は元の一覧へ戻るため、複数件を順に確認する場合も同じ条件から再開できます。
4. `送信先URL` が現在の受信先 URL と一致しているか、受信先側で route / token / IP allowlist などが変わっていないかを確認します。
5. `HTTP` が 4xx の場合は、受信先の認証・署名検証・payload validation を先に見ます。
6. `HTTP` が 5xx の場合は、受信先サービスの障害・timeout・一時的な処理失敗を先に見ます。
7. `エラー` に timeout や接続例外が出ている場合は、一覧の preview で分類の手掛かりを読み、必要なら `詳細` で response body や送信先 URL と合わせてネットワーク疎通、DNS、TLS、受信先の稼働状態を確認します。
8. `mail / webhook の継続失敗` として監視側で拾われている場合は、[監視・アラート設計](./監視・アラート設計.md) の外部依存確認と合わせて見ます。

## 手動再送の扱い

current 実装では、失敗した delivery だけを管理画面から 1 件ずつ、または `失敗` 表示中の表示範囲のうち再送可能な delivery だけをまとめて手動再送できます。まとめて再送の対象は failed かつ endpoint が有効な delivery に限定され、停止中 endpoint、成功済み、送信待ちの delivery は対象外です。自動 retry queue、scheduled retry、指数 backoff、retry metadata、親子 delivery relation はまだありません。

手動再送するときは次を確認します。

1. 送信履歴を `失敗` に絞り込み、対象 delivery の endpoint と event type を確認します。
2. まとめて再送を使う場合は、画面に表示される対象件数、endpoint、event type の内訳を確認します。
3. 受信先側で同じ event を再処理しても問題ないかを確認します。受信側は `X-Docs-Portal-Delivery` などの delivery identifier を冪等キーとして扱えるようにしておくのが安全です。
4. 対象行に一覧行の `再送` ボタンが出ていること、詳細画面では `この履歴を1件再送` ボタンが出ていること、または `失敗` 表示中に `表示中の失敗Webhookをまとめて再送` ボタンが出ていることを確認します。failed ではない delivery、または停止中 endpoint の delivery は再送できません。
5. 確認ダイアログで、送信履歴 1 件または表示中の再送可能な失敗 delivery を現在の Webhook 設定で再送することと、受信先側の重複処理に注意することを確認して実行します。
6. 1 件再送は、詳細画面から実行しても元の status filter 一覧または送信履歴検索一覧へ戻ります。`失敗` 表示や検索一覧から詳細へ入った場合は、再送後も同じ条件で結果確認を再開できます。
7. 再送結果は元 delivery を上書きせず、新しい `WebhookDelivery` として送信履歴に残ります。実行後は送信履歴の新しい行で status / HTTP / error を確認します。

再送できない delivery を無理に再送するためにコードやデータを直接操作する必要がある場合は、この runbook だけで判断せず、対象 event、受信先の冪等性、重複送信時の扱いを人間確認に回してください。

## 関連 docs

- [Webhook・外部API連携方針](./Webhook・外部API連携方針.md)
- [アクセス申請・同意管理・Webhook運用runbook](./アクセス申請・同意管理・Webhook運用runbook.md)
- [監視・アラート設計](./監視・アラート設計.md)
