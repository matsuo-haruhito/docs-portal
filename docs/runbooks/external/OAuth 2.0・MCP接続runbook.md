# OAuth 2.0・MCP接続runbook

## 目的

AIエージェントをdocs-portalのMCP endpointへ接続し、利用者権限と文書の正本区分を維持したまま案件・文書を参照、改訂、公開する。

## 前提

- productionでは `MCP_PUBLIC_BASE_URL=https://<公開host>` を設定する
- redirect URIはHTTPSを使う。loopback clientだけ `localhost` / `127.0.0.1` / `[::1]` のHTTPを許可する
- clientはAuthorization Code + PKCE S256に対応していること
- dynamic client registrationは提供しない。OAuth clientは運用者が登録する
- docs-portal、sales-mgt、GitHubには別々のcredentialを設定し、tokenやsecretを相互に転送しない

## OAuth client登録

public PKCE clientは、app containerまたはproduction consoleで次のように登録する。redirect URIとscopeは接続先clientに必要な値だけ指定する。

```bash
OAUTH_CLIENT_NAME='AIエージェント' \
OAUTH_REDIRECT_URI='http://localhost:6274/callback' \
OAUTH_SCOPES='documents:read documents:write documents:publish' \
bundle exec rails runner '
  application = Doorkeeper::Application.create!(
    name: ENV.fetch("OAUTH_CLIENT_NAME"),
    redirect_uri: ENV.fetch("OAUTH_REDIRECT_URI"),
    scopes: ENV.fetch("OAUTH_SCOPES"),
    confidential: false
  )
  puts application.uid
'
```

出力されたclient IDだけをclientへ設定する。public PKCE clientにはclient secretを発行しない。登録済みclientのscopeやredirect URIを広げる場合は、新しい接続先が必要とする理由を確認してから変更する。

## Endpoint

`MCP_PUBLIC_BASE_URL` が `https://docs.example.com` の場合:

| 用途 | URL |
|---|---|
| Authorization Server Metadata | `https://docs.example.com/.well-known/oauth-authorization-server` |
| Protected Resource Metadata | `https://docs.example.com/.well-known/oauth-protected-resource` |
| 認可 | `https://docs.example.com/oauth/authorize` |
| token | `https://docs.example.com/oauth/token` |
| revoke | `https://docs.example.com/oauth/revoke` |
| MCP Streamable HTTP | `https://docs.example.com/mcp` |

MCP requestは`Authorization: Bearer <access token>`を付ける。access tokenは1時間、認可codeは10分で失効し、refresh tokenを利用できる。

## Scope

| Scope | 許可される操作 |
|---|---|
| `documents:read` | 案件一覧、文書検索・詳細、案件AI context、正本更新先の確認 |
| `documents:write` | docs-portal正本Markdownの改訂previewと新しいdraft版のapply、draft版の品質確認 |
| `documents:publish` | 品質確認済みdraft版の公開previewとpublish |

scopeは既存のUser / Project / Document権限を置き換えない。externalとcompany_master_adminはwrite/publish scopeを持っていても改訂・公開できない。

## 文書更新手順

1. `get_document_update_route` で `source_authority` と更新先を確認する。
2. `docs_portal` の場合は `preview_document_revision` を呼び、差分対象・本文digest・確認tokenを確認する。
3. 同じ本文とmetadata、確認token、一意な `idempotency_key` で `apply_document_revision` を呼ぶ。既存版は変更されず、新しいdraft版が作られる。
4. `check_document_revision` でerror・warningを確認する。
5. 公開する場合は `preview_document_publish` を呼び、品質結果と公開確認tokenを確認する。
6. 同じ版public ID、確認token、一意な `idempotency_key` で `publish_document_revision` を呼ぶ。

同じ操作の通信結果が不明な場合は、同じpayloadと同じidempotency keyで再送する。異なるpayloadへ同じkeyを再利用しない。

`github`、`sales_mgt`、`external_folder` の場合はdocs-portalで直接変更せず、routeが返すrepository・external ID・provider情報を使って正本側のMCPまたは同期フローへ引き継ぐ。

## Maintenance時

`READ_ONLY_MAINTENANCE=true` の間も参照、更新先確認、改訂preview、品質確認、公開preview、同一key・同一digestの確定済みreceipt再応答は利用できる。新しいdraft版のapplyとpublish、OAuth clientの作成・変更・revokeは停止する。

## 障害切り分け

- `401 invalid_token`: Authorization header、token期限・失効、利用者のactive状態を確認する
- `insufficient_scope`: clientにgrantしたscopeとtoolに必要なscopeを確認する
- `forbidden`: 利用者種別と既存案件・文書権限を確認する
- 正本不一致: `get_document_update_route` を再取得し、正本側へ引き継ぐ
- 確認token不一致・期限切れ: previewからやり直し、最新の本文・版・品質結果で再確認する
- maintenance拒否: read-only操作で状況を確認し、maintenance解除後に同じpreviewからではなく再previewして適用する

監査時はMCP access logと`McpMutationReceipt`を確認する。token、secret、文書本文をログやIssueへ貼らない。
