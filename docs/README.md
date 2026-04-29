# docs

このディレクトリは、この repo で運用する仕様・規約・方針の置き場です

## 文書一覧

- [アプリケーション仕様](./アプリケーション仕様.md)
- [コーディング規約](./コーディング規約.md)
- [テスト方針](./テスト方針.md)
- [publish.json 仕様と生成ルール](./publish.json%20仕様と生成ルール.md)
- [ローカル編集からポータル更新までの最小運用案](./ローカル編集からポータル更新までの最小運用案.md)
- [ToDo](./ToDo.md)

## 仕様概要

1. 識別子
   - DB id
   - public_id
   - code / slug
   - URL に出す ID

2. アクセス制御
   - internal user
   - admin user
   - company_master_admin user
   - external user
   - project membership
   - document permission
   - view/download

3. ドキュメント公開モデル
   - Document
   - DocumentVersion
   - DocumentFile
   - draft / published / archived
   - latest_version
   - バージョン管理あり / なし

4. Docusaurus 表示
   - build 成果物
   - site_build_path
   - rendered_site_available?
   - assets の扱い

5. 添付ファイル
   - Markdown は生ファイル表示
   - download 権限
   - content type / charset

6. Import
   - publish.json
   - version immutability
   - storage_key
   - build artifact

7. AccessLog
   - 記録対象
   - 記録しない対象
   - last_login_at は users 側で管理

8. 将来対応
   - 現時点の仕様に含めないものは [ToDo](./ToDo.md) に記載する
