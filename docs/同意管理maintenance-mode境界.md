# 同意管理 maintenance mode 境界

このメモは #4546 の first slice として、`READ_ONLY_MAINTENANCE` 中に同意管理で止める変更系操作と、止めずに read-only 確認として残す導線を整理します。

## 停止する操作

`READ_ONLY_MAINTENANCE` が有効な間、次の変更系操作は開始しません。

- `ConsentsController#create`
  - 未同意文面に対する `UserConsent` を作成しません。
  - 同意記録の IP address / user agent 記録も開始しません。
- `Admin::ConsentTermsController#create` / `#update` / `#destroy`
  - 同意文面の作成、本文・版・種別・再同意方針・状態の更新、削除を保存しません。
- `Admin::ProjectConsentSettingsController#create` / `#update` / `#destroy`
  - 案件と同意文面の紐付け、必須タイミング、状態の作成・更新・削除を保存しません。

停止時は利用者または admin がメンテナンス中であることを読める alert を表示します。

## read-only として残す導線

maintenance mode 中も、次は確認用の read-only 導線として残します。

- `GET /consents` の同意履歴と active 文面確認
- `GET /consents/new` の未同意文面確認
- `admin/consent_terms` の一覧、filter、edit 表示
- `admin/project_consent_settings` の一覧、filter、edit 表示、案件 / 同意文面 remote search と selected restore

これらは同意記録、同意文面、案件同意設定を保存・削除しない確認導線として扱います。

## 非目標

この slice では次を変更しません。

- 同意 policy、法務文面の妥当性、再同意条件
- 法務承認 workflow、契約締結 record、通知、期限、SLA
- `ConsentTerm` / `UserConsent` / `ProjectConsentSetting` schema や enum
- 権限 model、会社 / 案件 / 文書 permission model
- 全利用者向け変更系操作の一括停止

## 確認観点

request spec では次を確認します。

- maintenance mode ON で `UserConsent` が増えないこと
- maintenance mode ON で `ConsentTerm` が作成・更新・削除されないこと
- maintenance mode ON で `ProjectConsentSetting` が作成・更新・削除されないこと
- maintenance mode ON でも利用者側の履歴 / 確認画面、admin 側の一覧 / edit / remote search が読めること
- maintenance mode OFF の既存同意記録作成と admin CRUD は既存 request spec に残すこと
