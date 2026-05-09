class AddTableComments < ActiveRecord::Migration[8.1]
  TABLE_COMMENTS = {
    access_logs: "文書・ページ・添付ファイルへの閲覧やダウンロードなどのアクセス履歴",
    access_requests: "文書などに対する追加アクセス権限の申請",
    bulk_edit_dry_runs: "文書一括編集の事前確認結果と実行待ち状態",
    companies: "社外利用者の所属会社・ドメイン",
    consent_terms: "初回表示やダウンロード前に同意を求める規約本文",
    document_approval_requests: "文書に対する確認依頼と承認・差し戻し状態",
    document_bookmarks: "利用者ごとのお気に入り・後で読む文書",
    document_catalog_items: "文書カタログに含める文書の並びと補足",
    document_catalogs: "案件ごとの文書カタログ",
    document_delivery_logs: "文書・文書セットの外部送付履歴",
    document_files: "文書バージョンに紐づく添付ファイル・元ファイル",
    document_keywords: "文書検索用のキーワード",
    document_permissions: "会社または利用者単位の文書アクセス権限",
    document_relations: "文書間の参照・置き換え・関連関係",
    document_review_comments: "文書レビューコメント・Q&A・指摘事項",
    document_set_items: "文書セットに含める文書・版の並びと補足",
    document_sets: "用途別にまとめた文書セット",
    document_taggings: "文書とタグの紐づけ",
    document_tags: "文書分類用タグ",
    document_versions: "文書の版情報・生成済みHTML・公開期間",
    documents: "案件に属する文書の基本情報と公開方針",
    git_import_runs: "Gitリポジトリ取り込み処理の実行履歴",
    git_import_sources: "案件に紐づくGit取り込み元設定",
    import_dry_runs: "Git取り込みの事前確認結果と実行待ち状態",
    notification_events: "利用者へ通知するイベント本体",
    notification_receipts: "通知イベントに対する利用者ごとの既読状態",
    project_consent_settings: "案件ごとの同意規約適用設定",
    project_memberships: "利用者と案件の参加関係・役割",
    projects: "案件の基本情報",
    read_confirmations: "利用者ごとの文書既読確認",
    user_consents: "利用者が同意した規約の記録",
    users: "ログイン利用者と権限種別"
  }.freeze

  def change
    TABLE_COMMENTS.each do |table_name, comment|
      change_table_comment table_name, from: nil, to: comment
    end
  end
end
