# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_05_18_000100) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"

  create_table "access_logs", id: { comment: "ID" }, comment: "アクセスログ", force: :cascade do |t|
    t.datetime "accessed_at", null: false, comment: "アクセス日時"
    t.integer "action_type", null: false, comment: "操作種別"
    t.bigint "company_id", comment: "会社ID"
    t.datetime "created_at", null: false, comment: "作成日時"
    t.bigint "document_id", comment: "文書ID"
    t.bigint "document_version_id", comment: "文書バージョンID"
    t.string "ip_address", comment: "IPアドレス"
    t.bigint "project_id", comment: "案件ID"
    t.string "public_id", null: false, comment: "公開ID"
    t.string "target_name", comment: "対象名"
    t.string "target_type", null: false, comment: "対象種別"
    t.datetime "updated_at", null: false, comment: "更新日時"
    t.text "user_agent", comment: "ユーザーエージェント"
    t.bigint "user_id", comment: "利用者ID"
    t.index ["accessed_at", "id"], name: "index_access_logs_on_recent_order", order: :desc
    t.index ["action_type", "accessed_at", "id"], name: "index_access_logs_on_action_type_recent", order: { accessed_at: :desc, id: :desc }
    t.index ["company_id", "accessed_at", "id"], name: "index_access_logs_on_company_recent", order: { accessed_at: :desc, id: :desc }
    t.index ["company_id"], name: "index_access_logs_on_company_id"
    t.index ["document_id", "accessed_at", "id"], name: "index_access_logs_on_document_recent", order: { accessed_at: :desc, id: :desc }
    t.index ["document_id"], name: "index_access_logs_on_document_id"
    t.index ["document_version_id"], name: "index_access_logs_on_document_version_id"
    t.index ["project_id", "accessed_at", "id"], name: "index_access_logs_on_project_recent", order: { accessed_at: :desc, id: :desc }
    t.index ["project_id"], name: "index_access_logs_on_project_id"
    t.index ["public_id"], name: "index_access_logs_on_public_id", unique: true
    t.index ["target_type", "accessed_at", "id"], name: "index_access_logs_on_target_type_recent", order: { accessed_at: :desc, id: :desc }
    t.index ["user_id", "accessed_at", "id"], name: "index_access_logs_on_user_recent", order: { accessed_at: :desc, id: :desc }
    t.index ["user_id"], name: "index_access_logs_on_user_id"
  end

  create_table "access_requests", id: { comment: "ID" }, comment: "アクセス申請", force: :cascade do |t|
    t.datetime "approved_at", comment: "承認日時"
    t.bigint "approver_id", comment: "承認者ID"
    t.datetime "cancelled_at", comment: "キャンセル日時"
    t.datetime "created_at", null: false, comment: "作成日時"
    t.datetime "expires_at", comment: "有効期限日時"
    t.string "public_id", null: false, comment: "公開ID"
    t.text "reason", null: false, comment: "申請理由"
    t.datetime "rejected_at", comment: "却下日時"
    t.text "rejection_reason", comment: "却下理由"
    t.bigint "requestable_id", null: false, comment: "申請対象ID"
    t.string "requestable_type", null: false, comment: "申請対象種別"
    t.integer "requested_access_level", default: 0, null: false, comment: "申請アクセス権限"
    t.bigint "requester_id", null: false, comment: "申請者ID"
    t.integer "status", default: 0, null: false, comment: "ステータス"
    t.datetime "updated_at", null: false, comment: "更新日時"
    t.index ["approved_at"], name: "index_access_requests_on_approved_at"
    t.index ["approver_id"], name: "index_access_requests_on_approver_id"
    t.index ["expires_at"], name: "index_access_requests_on_expires_at"
    t.index ["public_id"], name: "index_access_requests_on_public_id", unique: true
    t.index ["rejected_at"], name: "index_access_requests_on_rejected_at"
    t.index ["requestable_type", "requestable_id"], name: "index_access_requests_on_requestable_type_and_requestable_id"
    t.index ["requested_access_level"], name: "index_access_requests_on_requested_access_level"
    t.index ["requester_id", "requestable_type", "requestable_id", "requested_access_level", "status"], name: "index_access_requests_unique_pending", unique: true, where: "(status = 0)"
    t.index ["requester_id"], name: "index_access_requests_on_requester_id"
    t.index ["status"], name: "index_access_requests_on_status"
  end

  create_table "bulk_edit_dry_runs", id: { comment: "ID" }, comment: "一括編集ドライラン", force: :cascade do |t|
    t.datetime "confirmed_at", comment: "確認日時"
    t.bigint "confirmed_by_id", comment: "確認者ID"
    t.datetime "created_at", null: false, comment: "作成日時"
    t.bigint "created_by_id", null: false, comment: "作成者ID"
    t.json "errors_json", default: [], null: false, comment: "エラーJSON"
    t.datetime "expires_at", comment: "有効期限日時"
    t.integer "operation_type", default: 0, null: false, comment: "操作種別"
    t.json "params_json", default: {}, null: false, comment: "パラメータJSON"
    t.bigint "project_id", comment: "案件ID"
    t.string "public_id", null: false, comment: "公開ID"
    t.json "result_json", default: {}, null: false, comment: "結果JSON"
    t.integer "status", default: 0, null: false, comment: "ステータス"
    t.json "summary_json", default: {}, null: false, comment: "サマリーJSON"
    t.json "target_document_ids", default: [], null: false, comment: "対象文書ID一覧"
    t.datetime "updated_at", null: false, comment: "更新日時"
    t.json "warnings_json", default: [], null: false, comment: "警告JSON"
    t.index ["confirmed_by_id"], name: "index_bulk_edit_dry_runs_on_confirmed_by_id"
    t.index ["created_by_id"], name: "index_bulk_edit_dry_runs_on_created_by_id"
    t.index ["operation_type"], name: "index_bulk_edit_dry_runs_on_operation_type"
    t.index ["project_id"], name: "index_bulk_edit_dry_runs_on_project_id"
    t.index ["public_id"], name: "index_bulk_edit_dry_runs_on_public_id", unique: true
    t.index ["status"], name: "index_bulk_edit_dry_runs_on_status"
  end

  create_table "companies", id: { comment: "ID" }, comment: "会社", force: :cascade do |t|
    t.boolean "active", default: true, null: false, comment: "有効フラグ"
    t.datetime "created_at", null: false, comment: "作成日時"
    t.string "domain", null: false, comment: "ドメイン"
    t.string "name", comment: "会社名"
    t.string "public_id", null: false, comment: "公開ID"
    t.datetime "updated_at", null: false, comment: "更新日時"
    t.index ["domain"], name: "index_companies_on_domain", unique: true
    t.index ["public_id"], name: "index_companies_on_public_id", unique: true
  end

  create_table "consent_terms", id: { comment: "ID" }, comment: "同意規約", force: :cascade do |t|
    t.boolean "active", default: true, null: false, comment: "有効フラグ"
    t.text "body", null: false, comment: "本文"
    t.integer "consent_scope", default: 0, null: false, comment: "同意範囲"
    t.datetime "created_at", null: false, comment: "作成日時"
    t.string "public_id", null: false, comment: "公開ID"
    t.integer "requirement_timing", default: 0, null: false, comment: "要求タイミング"
    t.string "title", null: false, comment: "タイトル"
    t.datetime "updated_at", null: false, comment: "更新日時"
    t.string "version_label", null: false, comment: "バージョンラベル"
    t.index ["active"], name: "index_consent_terms_on_active"
    t.index ["consent_scope"], name: "index_consent_terms_on_consent_scope"
    t.index ["public_id"], name: "index_consent_terms_on_public_id", unique: true
    t.index ["requirement_timing"], name: "index_consent_terms_on_requirement_timing"
    t.index ["title", "version_label"], name: "index_consent_terms_on_title_and_version_label", unique: true
  end

  create_table "document_approval_requests", id: { comment: "ID" }, comment: "文書承認依頼", force: :cascade do |t|
    t.bigint "acted_by_id", comment: "対応者ID"
    t.datetime "approved_at", comment: "承認日時"
    t.bigint "approver_id", comment: "承認者ID"
    t.text "body", comment: "本文"
    t.datetime "cancelled_at", comment: "キャンセル日時"
    t.datetime "created_at", null: false, comment: "作成日時"
    t.bigint "document_id", null: false, comment: "文書ID"
    t.string "public_id", null: false, comment: "公開ID"
    t.bigint "requester_id", null: false, comment: "申請者ID"
    t.integer "status", default: 0, null: false, comment: "ステータス"
    t.string "title", null: false, comment: "タイトル"
    t.datetime "updated_at", null: false, comment: "更新日時"
    t.index ["acted_by_id"], name: "index_document_approval_requests_on_acted_by_id"
    t.index ["approved_at"], name: "index_document_approval_requests_on_approved_at"
    t.index ["approver_id"], name: "index_document_approval_requests_on_approver_id"
    t.index ["cancelled_at"], name: "index_document_approval_requests_on_cancelled_at"
    t.index ["document_id"], name: "index_document_approval_requests_on_document_id"
    t.index ["public_id"], name: "index_document_approval_requests_on_public_id", unique: true
    t.index ["requester_id"], name: "index_document_approval_requests_on_requester_id"
    t.index ["status"], name: "index_document_approval_requests_on_status"
  end

  create_table "document_bookmarks", id: { comment: "ID" }, comment: "文書ブックマーク", force: :cascade do |t|
    t.integer "bookmark_type", default: 0, null: false, comment: "ブックマーク種別"
    t.datetime "created_at", null: false, comment: "作成日時"
    t.bigint "document_id", null: false, comment: "文書ID"
    t.string "public_id", null: false, comment: "公開ID"
    t.datetime "updated_at", null: false, comment: "更新日時"
    t.bigint "user_id", null: false, comment: "利用者ID"
    t.index ["document_id"], name: "index_document_bookmarks_on_document_id"
    t.index ["public_id"], name: "index_document_bookmarks_on_public_id", unique: true
    t.index ["user_id", "document_id", "bookmark_type"], name: "index_document_bookmarks_unique_user_document_type", unique: true
    t.index ["user_id"], name: "index_document_bookmarks_on_user_id"
  end

  create_table "document_catalog_items", id: { comment: "ID" }, comment: "文書カタログ項目", force: :cascade do |t|
    t.datetime "created_at", null: false, comment: "作成日時"
    t.bigint "document_catalog_id", null: false, comment: "文書カタログID"
    t.bigint "document_id", null: false, comment: "文書ID"
    t.text "note", comment: "備考"
    t.integer "sort_order", default: 0, null: false, comment: "表示順"
    t.datetime "updated_at", null: false, comment: "更新日時"
    t.index ["document_catalog_id", "document_id"], name: "index_document_catalog_items_unique_catalog_document", unique: true
    t.index ["document_catalog_id"], name: "index_document_catalog_items_on_document_catalog_id"
    t.index ["document_id"], name: "index_document_catalog_items_on_document_id"
    t.index ["sort_order"], name: "index_document_catalog_items_on_sort_order"
  end

  create_table "document_catalogs", id: { comment: "ID" }, comment: "文書カタログ", force: :cascade do |t|
    t.integer "audience_type", default: 0, null: false, comment: "対象者種別"
    t.datetime "created_at", null: false, comment: "作成日時"
    t.text "description", comment: "説明"
    t.string "name", null: false, comment: "名称"
    t.bigint "project_id", null: false, comment: "案件ID"
    t.string "public_id", null: false, comment: "公開ID"
    t.integer "sort_order", default: 0, null: false, comment: "表示順"
    t.datetime "updated_at", null: false, comment: "更新日時"
    t.integer "visibility_policy", default: 0, null: false, comment: "公開方針"
    t.index ["audience_type"], name: "index_document_catalogs_on_audience_type"
    t.index ["project_id", "name"], name: "index_document_catalogs_on_project_id_and_name", unique: true
    t.index ["project_id"], name: "index_document_catalogs_on_project_id"
    t.index ["public_id"], name: "index_document_catalogs_on_public_id", unique: true
    t.index ["sort_order"], name: "index_document_catalogs_on_sort_order"
    t.index ["visibility_policy"], name: "index_document_catalogs_on_visibility_policy"
  end

  create_table "document_delivery_logs", id: { comment: "ID" }, comment: "文書送付ログ", force: :cascade do |t|
    t.text "bcc_addresses", comment: "BCCアドレス"
    t.text "body", null: false, comment: "本文"
    t.text "cc_addresses", comment: "CCアドレス"
    t.datetime "created_at", null: false, comment: "作成日時"
    t.integer "delivery_type", default: 0, null: false, comment: "送付種別"
    t.bigint "document_id", comment: "文書ID"
    t.text "error_message", comment: "エラーメッセージ"
    t.bigint "project_id", null: false, comment: "案件ID"
    t.string "public_id", null: false, comment: "公開ID"
    t.bigint "sender_id", null: false, comment: "送信者ID"
    t.datetime "sent_at", comment: "送信日時"
    t.integer "status", default: 0, null: false, comment: "ステータス"
    t.string "subject", null: false, comment: "件名"
    t.text "to_addresses", null: false, comment: "宛先アドレス"
    t.datetime "updated_at", null: false, comment: "更新日時"
    t.index ["delivery_type"], name: "index_document_delivery_logs_on_delivery_type"
    t.index ["document_id"], name: "index_document_delivery_logs_on_document_id"
    t.index ["project_id"], name: "index_document_delivery_logs_on_project_id"
    t.index ["public_id"], name: "index_document_delivery_logs_on_public_id", unique: true
    t.index ["sender_id"], name: "index_document_delivery_logs_on_sender_id"
    t.index ["sent_at"], name: "index_document_delivery_logs_on_sent_at"
    t.index ["status"], name: "index_document_delivery_logs_on_status"
  end

  create_table "document_file_google_drive_preview_uploads", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.bigint "document_file_id", null: false
    t.string "drive_file_id", null: false
    t.string "drive_web_view_link"
    t.datetime "expires_at", null: false
    t.string "fingerprint", null: false
    t.text "last_error_message"
    t.string "public_id", null: false
    t.datetime "updated_at", null: false
    t.datetime "uploaded_at", null: false
    t.index ["document_file_id", "fingerprint", "deleted_at"], name: "idx_google_preview_uploads_on_file_fingerprint_deleted"
    t.index ["document_file_id"], name: "idx_google_preview_uploads_on_document_file"
    t.index ["expires_at", "deleted_at"], name: "idx_google_preview_uploads_on_expires_deleted"
    t.index ["public_id"], name: "index_document_file_google_drive_preview_uploads_on_public_id", unique: true
  end

  create_table "document_file_microsoft_graph_preview_uploads", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.bigint "document_file_id", null: false
    t.string "drive_id", null: false
    t.string "drive_item_id", null: false
    t.string "drive_item_path", null: false
    t.datetime "expires_at", null: false
    t.string "fingerprint", null: false
    t.text "last_error_message"
    t.bigint "microsoft_graph_connection_id", null: false
    t.string "public_id", null: false
    t.datetime "updated_at", null: false
    t.datetime "uploaded_at", null: false
    t.index ["document_file_id", "microsoft_graph_connection_id", "fingerprint", "deleted_at"], name: "idx_graph_preview_uploads_on_file_conn_fingerprint_deleted"
    t.index ["document_file_id"], name: "idx_graph_preview_uploads_on_document_file"
    t.index ["expires_at", "deleted_at"], name: "idx_graph_preview_uploads_on_expires_deleted"
    t.index ["microsoft_graph_connection_id"], name: "idx_graph_preview_uploads_on_connection"
    t.index ["public_id"], name: "idx_on_public_id_4faf38844d", unique: true
  end

  create_table "document_files", id: { comment: "ID" }, comment: "文書ファイル", force: :cascade do |t|
    t.string "content_type", null: false, comment: "コンテンツ種別"
    t.datetime "created_at", null: false, comment: "作成日時"
    t.bigint "document_version_id", null: false, comment: "文書バージョンID"
    t.string "file_name", null: false, comment: "ファイル名"
    t.bigint "file_size", default: 0, null: false, comment: "ファイルサイズ"
    t.string "public_id", null: false, comment: "公開ID"
    t.text "scan_error_message", comment: "スキャンエラーメッセージ"
    t.integer "scan_status", default: 0, null: false, comment: "スキャンステータス"
    t.datetime "scanned_at", comment: "スキャン日時"
    t.text "search_text", comment: "検索テキスト"
    t.integer "sort_order", default: 0, null: false, comment: "表示順"
    t.string "storage_key", null: false, comment: "ストレージキー"
    t.datetime "updated_at", null: false, comment: "更新日時"
    t.index ["document_version_id"], name: "index_document_files_on_document_version_id"
    t.index ["file_name"], name: "index_document_files_on_file_name_trigram", opclass: :gin_trgm_ops, using: :gin
    t.index ["public_id"], name: "index_document_files_on_public_id", unique: true
    t.index ["scan_status"], name: "index_document_files_on_scan_status"
    t.index ["search_text"], name: "index_document_files_on_search_text_trigram", opclass: :gin_trgm_ops, using: :gin
    t.index ["storage_key"], name: "index_document_files_on_storage_key", unique: true
    t.check_constraint "file_size >= 0", name: "document_files_file_size_non_negative"
    t.check_constraint "sort_order >= 0", name: "document_files_sort_order_non_negative"
  end

  create_table "document_keywords", id: { comment: "ID" }, comment: "文書キーワード", force: :cascade do |t|
    t.datetime "created_at", null: false, comment: "作成日時"
    t.bigint "document_id", null: false, comment: "文書ID"
    t.string "keyword", null: false, comment: "キーワード"
    t.string "normalized_keyword", null: false, comment: "正規化キーワード"
    t.string "public_id", null: false, comment: "公開ID"
    t.integer "sort_order", default: 0, null: false, comment: "表示順"
    t.datetime "updated_at", null: false, comment: "更新日時"
    t.index ["document_id", "normalized_keyword"], name: "index_document_keywords_on_document_id_and_normalized_keyword", unique: true
    t.index ["document_id"], name: "index_document_keywords_on_document_id"
    t.index ["keyword"], name: "index_document_keywords_on_keyword_trigram", opclass: :gin_trgm_ops, using: :gin
    t.index ["normalized_keyword"], name: "index_document_keywords_on_normalized_keyword"
    t.index ["normalized_keyword"], name: "index_document_keywords_on_normalized_keyword_trigram", opclass: :gin_trgm_ops, using: :gin
    t.index ["public_id"], name: "index_document_keywords_on_public_id", unique: true
    t.check_constraint "sort_order >= 0", name: "document_keywords_sort_order_non_negative"
  end

  create_table "document_permissions", id: { comment: "ID" }, comment: "文書権限", force: :cascade do |t|
    t.integer "access_level", default: 0, null: false, comment: "アクセス権限"
    t.bigint "company_id", comment: "会社ID"
    t.datetime "created_at", null: false, comment: "作成日時"
    t.bigint "document_id", null: false, comment: "文書ID"
    t.string "public_id", null: false, comment: "公開ID"
    t.datetime "updated_at", null: false, comment: "更新日時"
    t.bigint "user_id", comment: "利用者ID"
    t.index ["company_id"], name: "index_document_permissions_on_company_id"
    t.index ["document_id", "company_id"], name: "index_document_permissions_unique_company_scope", unique: true, where: "((company_id IS NOT NULL) AND (user_id IS NULL))"
    t.index ["document_id", "user_id"], name: "index_document_permissions_unique_user_scope", unique: true, where: "((user_id IS NOT NULL) AND (company_id IS NULL))"
    t.index ["document_id"], name: "index_document_permissions_on_document_id"
    t.index ["public_id"], name: "index_document_permissions_on_public_id", unique: true
    t.index ["user_id"], name: "index_document_permissions_on_user_id"
  end

  create_table "document_relations", id: { comment: "ID" }, comment: "文書関連", force: :cascade do |t|
    t.datetime "created_at", null: false, comment: "作成日時"
    t.text "note", comment: "備考"
    t.string "public_id", null: false, comment: "公開ID"
    t.integer "relation_type", default: 0, null: false, comment: "関連種別"
    t.integer "sort_order", default: 0, null: false, comment: "表示順"
    t.bigint "source_document_id", null: false, comment: "元文書ID"
    t.bigint "target_document_id", null: false, comment: "先文書ID"
    t.datetime "updated_at", null: false, comment: "更新日時"
    t.index ["public_id"], name: "index_document_relations_on_public_id", unique: true
    t.index ["source_document_id", "target_document_id", "relation_type"], name: "index_document_relations_unique_relation", unique: true
    t.index ["source_document_id"], name: "index_document_relations_on_source_document_id"
    t.index ["target_document_id"], name: "index_document_relations_on_target_document_id"
    t.check_constraint "sort_order >= 0", name: "document_relations_sort_order_non_negative"
    t.check_constraint "source_document_id <> target_document_id", name: "document_relations_source_target_different"
  end

  create_table "document_review_comments", id: { comment: "ID" }, comment: "文書レビューコメント", force: :cascade do |t|
    t.bigint "author_id", null: false, comment: "投稿者ID"
    t.text "body", null: false, comment: "本文"
    t.integer "comment_type", default: 0, null: false, comment: "コメント種別"
    t.datetime "created_at", null: false, comment: "作成日時"
    t.bigint "document_id", null: false, comment: "文書ID"
    t.bigint "document_version_id", comment: "文書バージョンID"
    t.boolean "internal_only", default: true, null: false, comment: "社内限定フラグ"
    t.bigint "parent_id", comment: "親コメントID"
    t.string "public_id", null: false, comment: "公開ID"
    t.datetime "resolved_at", comment: "解決日時"
    t.bigint "resolved_by_id", comment: "解決者ID"
    t.string "source_path", comment: "ソースパス"
    t.integer "status", default: 0, null: false, comment: "ステータス"
    t.string "text_anchor_label", comment: "テキストアンカーラベル"
    t.string "text_anchor_path", comment: "テキストアンカーパス"
    t.string "text_anchor_type", comment: "テキストアンカー種別"
    t.integer "text_line_end", comment: "終了行"
    t.integer "text_line_start", comment: "開始行"
    t.datetime "updated_at", null: false, comment: "更新日時"
    t.index ["author_id"], name: "index_document_review_comments_on_author_id"
    t.index ["comment_type"], name: "index_document_review_comments_on_comment_type"
    t.index ["document_id"], name: "index_document_review_comments_on_document_id"
    t.index ["document_version_id"], name: "index_document_review_comments_on_document_version_id"
    t.index ["internal_only"], name: "index_document_review_comments_on_internal_only"
    t.index ["parent_id"], name: "index_document_review_comments_on_parent_id"
    t.index ["public_id"], name: "index_document_review_comments_on_public_id", unique: true
    t.index ["resolved_by_id"], name: "index_document_review_comments_on_resolved_by_id"
    t.index ["status"], name: "index_document_review_comments_on_status"
  end

  create_table "document_set_items", id: { comment: "ID" }, comment: "文書セット項目", force: :cascade do |t|
    t.datetime "created_at", null: false, comment: "作成日時"
    t.bigint "document_id", null: false, comment: "文書ID"
    t.bigint "document_set_id", null: false, comment: "文書セットID"
    t.bigint "document_version_id", comment: "文書バージョンID"
    t.text "note", comment: "備考"
    t.integer "sort_order", default: 0, null: false, comment: "表示順"
    t.datetime "updated_at", null: false, comment: "更新日時"
    t.index ["document_id"], name: "index_document_set_items_on_document_id"
    t.index ["document_set_id", "document_id"], name: "index_document_set_items_on_document_set_id_and_document_id", unique: true
    t.index ["document_set_id"], name: "index_document_set_items_on_document_set_id"
    t.index ["document_version_id"], name: "index_document_set_items_on_document_version_id"
    t.index ["sort_order"], name: "index_document_set_items_on_sort_order"
  end

  create_table "document_sets", id: { comment: "ID" }, comment: "文書セット", force: :cascade do |t|
    t.datetime "created_at", null: false, comment: "作成日時"
    t.bigint "created_by_id", comment: "作成者ID"
    t.text "description", comment: "説明"
    t.string "name", null: false, comment: "名称"
    t.bigint "project_id", null: false, comment: "案件ID"
    t.string "public_id", null: false, comment: "公開ID"
    t.integer "set_type", default: 0, null: false, comment: "セット種別"
    t.integer "sort_order", default: 0, null: false, comment: "表示順"
    t.datetime "updated_at", null: false, comment: "更新日時"
    t.integer "visibility_policy", default: 0, null: false, comment: "公開方針"
    t.index ["created_by_id"], name: "index_document_sets_on_created_by_id"
    t.index ["project_id", "name"], name: "index_document_sets_on_project_id_and_name", unique: true
    t.index ["project_id"], name: "index_document_sets_on_project_id"
    t.index ["public_id"], name: "index_document_sets_on_public_id", unique: true
    t.index ["set_type"], name: "index_document_sets_on_set_type"
    t.index ["sort_order"], name: "index_document_sets_on_sort_order"
    t.index ["visibility_policy"], name: "index_document_sets_on_visibility_policy"
  end

  create_table "document_taggings", id: { comment: "ID" }, comment: "文書タグ付け", force: :cascade do |t|
    t.datetime "created_at", null: false, comment: "作成日時"
    t.bigint "document_id", null: false, comment: "文書ID"
    t.bigint "document_tag_id", null: false, comment: "文書タグID"
    t.integer "sort_order", default: 0, null: false, comment: "表示順"
    t.datetime "updated_at", null: false, comment: "更新日時"
    t.index ["document_id", "document_tag_id"], name: "index_document_taggings_on_document_id_and_document_tag_id", unique: true
    t.index ["document_id"], name: "index_document_taggings_on_document_id"
    t.index ["document_tag_id"], name: "index_document_taggings_on_document_tag_id"
    t.check_constraint "sort_order >= 0", name: "document_taggings_sort_order_non_negative"
  end

  create_table "document_tags", id: { comment: "ID" }, comment: "文書タグ", force: :cascade do |t|
    t.datetime "created_at", null: false, comment: "作成日時"
    t.string "name", null: false, comment: "名称"
    t.string "normalized_name", null: false, comment: "正規化名称"
    t.string "public_id", null: false, comment: "公開ID"
    t.datetime "updated_at", null: false, comment: "更新日時"
    t.index ["normalized_name"], name: "index_document_tags_on_normalized_name", unique: true
    t.index ["public_id"], name: "index_document_tags_on_public_id", unique: true
  end

  create_table "document_versions", id: { comment: "ID" }, comment: "文書バージョン", force: :cascade do |t|
    t.text "changelog_summary", comment: "変更概要"
    t.datetime "created_at", null: false, comment: "作成日時"
    t.bigint "document_id", null: false, comment: "文書ID"
    t.string "markdown_entry_path", comment: "Markdownエントリーパス"
    t.text "notes", comment: "備考"
    t.string "pdf_snapshot_path", comment: "PDFスナップショットパス"
    t.string "public_id", null: false, comment: "公開ID"
    t.datetime "published_at", comment: "公開日時"
    t.bigint "published_by_user_id", comment: "公開者ID"
    t.datetime "published_from", comment: "公開開始日時"
    t.datetime "published_until", comment: "公開終了日時"
    t.text "search_body_text", comment: "検索本文"
    t.string "site_build_path", comment: "サイトビルドパス"
    t.string "snapshot_kind", comment: "スナップショット種別"
    t.string "source_basename", comment: "ソースベース名"
    t.string "source_commit_hash", null: false, comment: "ソースコミットハッシュ"
    t.string "source_directory", comment: "ソースディレクトリ"
    t.string "source_extension", comment: "ソース拡張子"
    t.string "source_file_name", comment: "ソースファイル名"
    t.string "source_relative_path", comment: "ソース相対パス"
    t.integer "status", default: 0, null: false, comment: "ステータス"
    t.datetime "updated_at", null: false, comment: "更新日時"
    t.string "version_label", null: false, comment: "バージョンラベル"
    t.index ["document_id", "version_label"], name: "index_document_versions_on_document_id_and_version_label", unique: true
    t.index ["document_id"], name: "index_document_versions_on_document_id"
    t.index ["public_id"], name: "index_document_versions_on_public_id", unique: true
    t.index ["published_by_user_id"], name: "index_document_versions_on_published_by_user_id"
    t.index ["published_from"], name: "index_document_versions_on_published_from"
    t.index ["published_until"], name: "index_document_versions_on_published_until"
    t.index ["search_body_text"], name: "index_document_versions_on_search_body_text_trigram", opclass: :gin_trgm_ops, using: :gin
    t.index ["site_build_path"], name: "index_document_versions_on_site_build_path"
    t.index ["snapshot_kind"], name: "index_document_versions_on_snapshot_kind"
    t.index ["source_basename"], name: "index_document_versions_on_source_basename"
    t.index ["source_directory"], name: "index_document_versions_on_source_directory"
    t.index ["source_directory"], name: "index_document_versions_on_source_directory_trigram", opclass: :gin_trgm_ops, using: :gin
    t.index ["source_extension"], name: "index_document_versions_on_source_extension"
    t.index ["source_file_name"], name: "index_document_versions_on_source_file_name_trigram", opclass: :gin_trgm_ops, using: :gin
    t.index ["source_relative_path"], name: "index_document_versions_on_source_relative_path"
    t.index ["source_relative_path"], name: "index_document_versions_on_source_relative_path_trigram", opclass: :gin_trgm_ops, using: :gin
    t.index ["version_label"], name: "index_document_versions_on_version_label_trigram", opclass: :gin_trgm_ops, using: :gin
  end

  create_table "documents", id: { comment: "ID" }, comment: "文書", force: :cascade do |t|
    t.datetime "archived_at", comment: "アーカイブ日時"
    t.bigint "archived_by_user_id", comment: "アーカイブ実行者ID"
    t.integer "category", default: 0, null: false, comment: "カテゴリ"
    t.datetime "created_at", null: false, comment: "作成日時"
    t.datetime "discard_candidate_at", comment: "廃棄候補日時"
    t.integer "document_kind", default: 0, null: false, comment: "文書種別"
    t.integer "importance_level", default: 2, null: false, comment: "重要度"
    t.bigint "latest_version_id", comment: "最新バージョンID"
    t.bigint "project_id", null: false, comment: "案件ID"
    t.string "public_id", null: false, comment: "公開ID"
    t.text "reading_note", comment: "読了メモ"
    t.integer "recommended_sort_order", default: 0, null: false, comment: "推奨表示順"
    t.datetime "retention_until", comment: "保存期限日時"
    t.string "slug", null: false, comment: "スラッグ"
    t.string "title", null: false, comment: "タイトル"
    t.datetime "updated_at", null: false, comment: "更新日時"
    t.integer "visibility_policy", default: 0, null: false, comment: "公開方針"
    t.index ["archived_at"], name: "index_documents_on_archived_at"
    t.index ["archived_by_user_id"], name: "index_documents_on_archived_by_user_id"
    t.index ["discard_candidate_at"], name: "index_documents_on_discard_candidate_at"
    t.index ["importance_level"], name: "index_documents_on_importance_level"
    t.index ["latest_version_id"], name: "index_documents_on_latest_version_id"
    t.index ["project_id", "slug"], name: "index_documents_on_project_id_and_slug", unique: true
    t.index ["project_id"], name: "index_documents_on_project_id"
    t.index ["public_id"], name: "index_documents_on_public_id", unique: true
    t.index ["recommended_sort_order"], name: "index_documents_on_recommended_sort_order"
    t.index ["retention_until"], name: "index_documents_on_retention_until"
    t.index ["slug"], name: "index_documents_on_slug_trigram", opclass: :gin_trgm_ops, using: :gin
    t.index ["title"], name: "index_documents_on_title_trigram", opclass: :gin_trgm_ops, using: :gin
  end

  create_table "external_folder_sync_items", id: { comment: "ID" }, comment: "外部フォルダ同期項目", force: :cascade do |t|
    t.string "checksum", comment: "チェックサム"
    t.datetime "created_at", null: false, comment: "作成日時"
    t.bigint "document_file_id", comment: "文書ファイルID"
    t.bigint "document_id", comment: "文書ID"
    t.bigint "document_version_id", comment: "文書バージョンID"
    t.bigint "external_folder_sync_source_id", null: false, comment: "外部フォルダ同期元ID"
    t.string "external_item_id", null: false, comment: "外部項目ID"
    t.datetime "external_modified_at", comment: "外部更新日時"
    t.string "external_parent_id", comment: "外部親ID"
    t.text "last_error_message", comment: "最終エラーメッセージ"
    t.string "mime_type", comment: "MIMEタイプ"
    t.string "name", null: false, comment: "名称"
    t.string "path", null: false, comment: "パス"
    t.datetime "portal_modified_at", comment: "ポータル更新日時"
    t.json "provider_metadata", default: {}, null: false, comment: "プロバイダーメタデータ"
    t.string "public_id", null: false, comment: "公開ID"
    t.bigint "size", comment: "サイズ"
    t.integer "sync_status", default: 0, null: false, comment: "同期ステータス"
    t.datetime "updated_at", null: false, comment: "更新日時"
    t.index ["document_file_id"], name: "index_external_folder_sync_items_on_document_file_id"
    t.index ["document_id"], name: "index_external_folder_sync_items_on_document_id"
    t.index ["document_version_id"], name: "index_external_folder_sync_items_on_document_version_id"
    t.index ["external_folder_sync_source_id", "external_item_id"], name: "idx_ext_sync_items_unique_source_item", unique: true
    t.index ["external_folder_sync_source_id"], name: "idx_ext_sync_items_on_source"
    t.index ["path"], name: "idx_ext_sync_items_on_path"
    t.index ["public_id"], name: "index_external_folder_sync_items_on_public_id", unique: true
    t.index ["sync_status", "updated_at"], name: "idx_ext_sync_items_on_status_updated_at"
  end

  create_table "external_folder_sync_runs", id: { comment: "ID" }, comment: "外部フォルダ同期実行", force: :cascade do |t|
    t.datetime "created_at", null: false, comment: "作成日時"
    t.text "error_message", comment: "エラーメッセージ"
    t.integer "errors_count", default: 0, null: false, comment: "エラー数"
    t.bigint "external_folder_sync_source_id", null: false, comment: "外部フォルダ同期元ID"
    t.datetime "finished_at", comment: "終了日時"
    t.integer "items_created_count", default: 0, null: false, comment: "作成項目数"
    t.integer "items_deleted_count", default: 0, null: false, comment: "削除項目数"
    t.integer "items_scanned_count", default: 0, null: false, comment: "走査項目数"
    t.integer "items_skipped_count", default: 0, null: false, comment: "スキップ項目数"
    t.integer "items_updated_count", default: 0, null: false, comment: "更新項目数"
    t.integer "mode", default: 0, null: false, comment: "実行モード"
    t.string "public_id", null: false, comment: "公開ID"
    t.json "result_json", default: [], null: false, comment: "結果JSON"
    t.datetime "started_at", comment: "開始日時"
    t.integer "status", default: 0, null: false, comment: "ステータス"
    t.json "summary_json", default: {}, null: false, comment: "サマリーJSON"
    t.datetime "updated_at", null: false, comment: "更新日時"
    t.index ["external_folder_sync_source_id"], name: "idx_ext_sync_runs_on_source"
    t.index ["mode", "started_at"], name: "idx_ext_sync_runs_on_mode_started_at"
    t.index ["public_id"], name: "index_external_folder_sync_runs_on_public_id", unique: true
    t.index ["status", "started_at"], name: "idx_ext_sync_runs_on_status_started_at"
  end

  create_table "external_folder_sync_sources", id: { comment: "ID" }, comment: "外部フォルダ同期元", force: :cascade do |t|
    t.text "auth_config", null: false, comment: "認証設定"
    t.integer "auth_type", default: 0, null: false, comment: "認証種別"
    t.integer "conflict_policy", default: 0, null: false, comment: "競合方針"
    t.datetime "created_at", null: false, comment: "作成日時"
    t.bigint "created_by_id", null: false, comment: "作成者ID"
    t.text "cursor", comment: "カーソル"
    t.boolean "enabled", default: true, null: false, comment: "有効フラグ"
    t.string "external_folder_id", null: false, comment: "外部フォルダID"
    t.string "external_folder_path", comment: "外部フォルダパス"
    t.string "folder_url", null: false, comment: "フォルダURL"
    t.text "last_error_message", comment: "最終エラーメッセージ"
    t.datetime "last_synced_at", comment: "最終同期日時"
    t.string "name", null: false, comment: "名称"
    t.bigint "project_id", null: false, comment: "案件ID"
    t.integer "provider", default: 0, null: false, comment: "プロバイダー"
    t.json "provider_metadata", default: {}, null: false, comment: "プロバイダーメタデータ"
    t.string "public_id", null: false, comment: "公開ID"
    t.integer "sync_direction", default: 0, null: false, comment: "同期方向"
    t.datetime "updated_at", null: false, comment: "更新日時"
    t.index ["created_by_id"], name: "index_external_folder_sync_sources_on_created_by_id"
    t.index ["project_id", "enabled"], name: "idx_ext_sync_sources_on_project_enabled"
    t.index ["project_id", "provider", "name"], name: "idx_ext_sync_sources_unique_project_provider_name", unique: true
    t.index ["project_id"], name: "index_external_folder_sync_sources_on_project_id"
    t.index ["provider", "auth_type"], name: "idx_ext_sync_sources_on_provider_auth_type"
    t.index ["provider", "external_folder_id"], name: "idx_ext_sync_sources_on_provider_folder"
    t.index ["public_id"], name: "index_external_folder_sync_sources_on_public_id", unique: true
  end

  create_table "external_folder_sync_subscriptions", id: { comment: "ID" }, comment: "外部フォルダ同期購読", force: :cascade do |t|
    t.string "callback_url", comment: "コールバックURL"
    t.datetime "created_at", null: false, comment: "作成日時"
    t.datetime "expires_at", comment: "有効期限日時"
    t.bigint "external_folder_sync_source_id", null: false, comment: "外部フォルダ同期元ID"
    t.text "last_error_message", comment: "最終エラーメッセージ"
    t.datetime "last_renewed_at", comment: "最終更新日時"
    t.integer "provider", default: 0, null: false, comment: "プロバイダー"
    t.string "provider_channel_id", comment: "プロバイダーチャンネルID"
    t.json "provider_metadata", default: {}, null: false, comment: "プロバイダーメタデータ"
    t.string "provider_resource_id", comment: "プロバイダーリソースID"
    t.string "provider_subscription_id", comment: "プロバイダー購読ID"
    t.string "public_id", null: false, comment: "公開ID"
    t.integer "status", default: 0, null: false, comment: "ステータス"
    t.datetime "updated_at", null: false, comment: "更新日時"
    t.string "verification_token_digest", comment: "検証トークンダイジェスト"
    t.index ["external_folder_sync_source_id"], name: "idx_ext_sync_subscriptions_on_source"
    t.index ["provider", "provider_channel_id"], name: "idx_ext_sync_subscriptions_on_provider_channel"
    t.index ["provider", "provider_subscription_id"], name: "idx_ext_sync_subscriptions_on_provider_subscription"
    t.index ["public_id"], name: "index_external_folder_sync_subscriptions_on_public_id", unique: true
    t.index ["status", "expires_at"], name: "idx_ext_sync_subscriptions_on_status_expires_at"
  end

  create_table "external_folder_sync_webhook_events", id: { comment: "ID" }, comment: "外部フォルダ同期Webhookイベント", force: :cascade do |t|
    t.datetime "created_at", null: false, comment: "作成日時"
    t.text "error_message", comment: "エラーメッセージ"
    t.string "event_key", comment: "イベントキー"
    t.bigint "external_folder_sync_source_id", comment: "外部フォルダ同期元ID"
    t.bigint "external_folder_sync_subscription_id", comment: "外部フォルダ同期購読ID"
    t.json "headers_json", default: {}, null: false, comment: "ヘッダーJSON"
    t.json "payload_json", default: {}, null: false, comment: "ペイロードJSON"
    t.integer "provider", default: 0, null: false, comment: "プロバイダー"
    t.string "public_id", null: false, comment: "公開ID"
    t.datetime "received_at", null: false, comment: "受信日時"
    t.integer "status", default: 0, null: false, comment: "ステータス"
    t.datetime "updated_at", null: false, comment: "更新日時"
    t.index ["external_folder_sync_source_id"], name: "idx_ext_sync_webhook_events_on_source"
    t.index ["external_folder_sync_subscription_id"], name: "idx_ext_sync_webhook_events_on_subscription"
    t.index ["provider", "event_key"], name: "idx_ext_sync_webhook_events_unique_provider_event", unique: true
    t.index ["public_id"], name: "index_external_folder_sync_webhook_events_on_public_id", unique: true
    t.index ["status", "received_at"], name: "idx_ext_sync_webhook_events_on_status_received_at"
  end

  create_table "git_import_runs", id: { comment: "ID" }, comment: "Git取り込み実行", force: :cascade do |t|
    t.string "branch", null: false, comment: "ブランチ"
    t.string "commit_sha", comment: "コミットSHA"
    t.datetime "created_at", null: false, comment: "作成日時"
    t.text "error_message", comment: "エラーメッセージ"
    t.datetime "finished_at", comment: "終了日時"
    t.bigint "git_import_source_id", comment: "Git取り込み元ID"
    t.integer "import_mode", default: 0, null: false, comment: "取り込みモード"
    t.integer "provider", default: 0, null: false, comment: "プロバイダー"
    t.string "public_id", null: false, comment: "公開ID"
    t.string "repository_full_name", null: false, comment: "リポジトリ完全名"
    t.string "source_path", null: false, comment: "ソースパス"
    t.datetime "started_at", comment: "開始日時"
    t.integer "status", default: 0, null: false, comment: "ステータス"
    t.json "summary_json", default: {}, null: false, comment: "サマリーJSON"
    t.datetime "updated_at", null: false, comment: "更新日時"
    t.index ["commit_sha"], name: "index_git_import_runs_on_commit_sha"
    t.index ["git_import_source_id"], name: "index_git_import_runs_on_git_import_source_id"
    t.index ["public_id"], name: "index_git_import_runs_on_public_id", unique: true
    t.index ["status"], name: "index_git_import_runs_on_status"
  end

  create_table "git_import_sources", id: { comment: "ID" }, comment: "Git取り込み元", force: :cascade do |t|
    t.integer "auth_type", default: 0, null: false, comment: "認証種別"
    t.string "branch", default: "main", null: false, comment: "ブランチ"
    t.datetime "created_at", null: false, comment: "作成日時"
    t.bigint "created_by_id", null: false, comment: "作成者ID"
    t.string "credential_ref", comment: "認証情報参照"
    t.text "credential_secret", comment: "認証情報シークレット"
    t.boolean "enabled", default: true, null: false, comment: "有効フラグ"
    t.string "installation_id", comment: "インストールID"
    t.datetime "last_synced_at", comment: "最終同期日時"
    t.string "last_synced_commit_sha", comment: "最終同期コミットSHA"
    t.string "organization_name", comment: "組織名"
    t.bigint "project_id", null: false, comment: "案件ID"
    t.integer "provider", default: 0, null: false, comment: "プロバイダー"
    t.string "public_id", null: false, comment: "公開ID"
    t.string "repository_full_name", null: false, comment: "リポジトリ完全名"
    t.string "source_path", default: "docs", null: false, comment: "ソースパス"
    t.datetime "updated_at", null: false, comment: "更新日時"
    t.index ["created_by_id"], name: "index_git_import_sources_on_created_by_id"
    t.index ["enabled"], name: "index_git_import_sources_on_enabled"
    t.index ["project_id", "repository_full_name", "branch", "source_path"], name: "index_git_import_sources_unique_target", unique: true
    t.index ["project_id"], name: "index_git_import_sources_on_project_id"
    t.index ["public_id"], name: "index_git_import_sources_on_public_id", unique: true
    t.index ["repository_full_name"], name: "index_git_import_sources_on_repository_full_name"
  end

  create_table "import_dry_runs", id: { comment: "ID" }, comment: "取り込みドライラン", force: :cascade do |t|
    t.datetime "confirmed_at", comment: "確認日時"
    t.bigint "confirmed_by_id", comment: "確認者ID"
    t.datetime "created_at", null: false, comment: "作成日時"
    t.bigint "created_by_id", null: false, comment: "作成者ID"
    t.json "errors_json", default: [], null: false, comment: "エラーJSON"
    t.datetime "expires_at", comment: "有効期限日時"
    t.integer "import_mode", default: 0, null: false, comment: "取り込みモード"
    t.bigint "project_id", comment: "案件ID"
    t.string "public_id", null: false, comment: "公開ID"
    t.json "result_json", default: {}, null: false, comment: "結果JSON"
    t.string "source_commit_hash", comment: "ソースコミットハッシュ"
    t.integer "status", default: 0, null: false, comment: "ステータス"
    t.json "summary_json", default: {}, null: false, comment: "サマリーJSON"
    t.datetime "updated_at", null: false, comment: "更新日時"
    t.json "warnings_json", default: [], null: false, comment: "警告JSON"
    t.index ["confirmed_by_id"], name: "index_import_dry_runs_on_confirmed_by_id"
    t.index ["created_by_id"], name: "index_import_dry_runs_on_created_by_id"
    t.index ["import_mode"], name: "index_import_dry_runs_on_import_mode"
    t.index ["project_id"], name: "index_import_dry_runs_on_project_id"
    t.index ["public_id"], name: "index_import_dry_runs_on_public_id", unique: true
    t.index ["status"], name: "index_import_dry_runs_on_status"
  end

  create_table "import_route_settings", id: { comment: "ID" }, comment: "取り込みルート設定", force: :cascade do |t|
    t.datetime "created_at", null: false, comment: "作成日時"
    t.bigint "project_id", comment: "案件ID"
    t.string "route_key", null: false, comment: "ルートキー"
    t.string "setting_key", null: false, comment: "設定キー"
    t.string "setting_value", null: false, comment: "設定値"
    t.datetime "updated_at", null: false, comment: "更新日時"
    t.index ["project_id", "route_key", "setting_key"], name: "index_import_route_settings_project_unique", unique: true, where: "(project_id IS NOT NULL)"
    t.index ["project_id"], name: "index_import_route_settings_on_project_id"
    t.index ["route_key", "setting_key"], name: "index_import_route_settings_global_unique", unique: true, where: "(project_id IS NULL)"
  end

  create_table "microsoft_graph_connections", id: { comment: "ID" }, comment: "Microsoft Graph接続", force: :cascade do |t|
    t.integer "auth_type", default: 0, null: false, comment: "認証種別"
    t.string "client_id", null: false, comment: "クライアントID"
    t.text "client_secret", null: false, comment: "クライアントシークレット"
    t.datetime "created_at", null: false, comment: "作成日時"
    t.bigint "created_by_id", null: false, comment: "作成者ID"
    t.string "drive_id", null: false, comment: "ドライブID"
    t.boolean "enabled", default: true, null: false, comment: "有効フラグ"
    t.string "name", null: false, comment: "名称"
    t.string "preview_folder_path", default: "docs-portal-previews", null: false, comment: "プレビューフォルダパス"
    t.bigint "project_id", null: false, comment: "案件ID"
    t.string "public_id", null: false, comment: "公開ID"
    t.string "site_id", comment: "サイトID"
    t.string "tenant_id", null: false, comment: "テナントID"
    t.datetime "updated_at", null: false, comment: "更新日時"
    t.index ["created_by_id"], name: "index_microsoft_graph_connections_on_created_by_id"
    t.index ["drive_id"], name: "index_microsoft_graph_connections_on_drive_id"
    t.index ["project_id", "enabled"], name: "index_microsoft_graph_connections_on_project_id_and_enabled"
    t.index ["project_id", "name"], name: "index_microsoft_graph_connections_on_project_id_and_name", unique: true
    t.index ["project_id"], name: "index_microsoft_graph_connections_on_project_id"
    t.index ["public_id"], name: "index_microsoft_graph_connections_on_public_id", unique: true
    t.index ["tenant_id"], name: "index_microsoft_graph_connections_on_tenant_id"
  end

  create_table "notification_events", id: { comment: "ID" }, comment: "通知イベント", force: :cascade do |t|
    t.bigint "actor_user_id", comment: "実行者ID"
    t.text "body", comment: "本文"
    t.datetime "created_at", null: false, comment: "作成日時"
    t.bigint "document_id", comment: "文書ID"
    t.bigint "document_version_id", comment: "文書バージョンID"
    t.integer "event_type", default: 0, null: false, comment: "イベント種別"
    t.datetime "occurred_at", null: false, comment: "発生日時"
    t.bigint "project_id", comment: "案件ID"
    t.string "public_id", null: false, comment: "公開ID"
    t.string "title", null: false, comment: "タイトル"
    t.datetime "updated_at", null: false, comment: "更新日時"
    t.index ["actor_user_id"], name: "index_notification_events_on_actor_user_id"
    t.index ["document_id"], name: "index_notification_events_on_document_id"
    t.index ["document_version_id"], name: "index_notification_events_on_document_version_id"
    t.index ["event_type"], name: "index_notification_events_on_event_type"
    t.index ["occurred_at"], name: "index_notification_events_on_occurred_at"
    t.index ["project_id"], name: "index_notification_events_on_project_id"
    t.index ["public_id"], name: "index_notification_events_on_public_id", unique: true
  end

  create_table "notification_receipts", id: { comment: "ID" }, comment: "通知受信", force: :cascade do |t|
    t.datetime "created_at", null: false, comment: "作成日時"
    t.bigint "notification_event_id", null: false, comment: "通知イベントID"
    t.string "public_id", null: false, comment: "公開ID"
    t.datetime "read_at", comment: "既読日時"
    t.datetime "updated_at", null: false, comment: "更新日時"
    t.bigint "user_id", null: false, comment: "利用者ID"
    t.index ["notification_event_id", "user_id"], name: "idx_notification_receipts_event_user", unique: true
    t.index ["notification_event_id"], name: "index_notification_receipts_on_notification_event_id"
    t.index ["public_id"], name: "index_notification_receipts_on_public_id", unique: true
    t.index ["user_id", "read_at"], name: "index_notification_receipts_on_user_id_and_read_at"
    t.index ["user_id"], name: "index_notification_receipts_on_user_id"
  end

  create_table "project_consent_settings", id: { comment: "ID" }, comment: "案件同意設定", force: :cascade do |t|
    t.bigint "consent_term_id", null: false, comment: "同意規約ID"
    t.datetime "created_at", null: false, comment: "作成日時"
    t.boolean "enabled", default: true, null: false, comment: "有効フラグ"
    t.bigint "project_id", null: false, comment: "案件ID"
    t.string "public_id", null: false, comment: "公開ID"
    t.integer "required_on", default: 0, null: false, comment: "要求対象"
    t.datetime "updated_at", null: false, comment: "更新日時"
    t.index ["consent_term_id"], name: "index_project_consent_settings_on_consent_term_id"
    t.index ["enabled"], name: "index_project_consent_settings_on_enabled"
    t.index ["project_id", "consent_term_id", "required_on"], name: "index_project_consent_settings_unique_requirement", unique: true
    t.index ["project_id"], name: "index_project_consent_settings_on_project_id"
    t.index ["public_id"], name: "index_project_consent_settings_on_public_id", unique: true
    t.index ["required_on"], name: "index_project_consent_settings_on_required_on"
  end

  create_table "project_memberships", id: { comment: "ID" }, comment: "案件メンバー", force: :cascade do |t|
    t.datetime "created_at", null: false, comment: "作成日時"
    t.bigint "project_id", null: false, comment: "案件ID"
    t.string "public_id", null: false, comment: "公開ID"
    t.integer "role", default: 0, null: false, comment: "役割"
    t.datetime "updated_at", null: false, comment: "更新日時"
    t.bigint "user_id", null: false, comment: "利用者ID"
    t.index ["project_id", "user_id"], name: "index_project_memberships_on_project_id_and_user_id", unique: true
    t.index ["project_id"], name: "index_project_memberships_on_project_id"
    t.index ["public_id"], name: "index_project_memberships_on_public_id", unique: true
    t.index ["user_id"], name: "index_project_memberships_on_user_id"
  end

  create_table "projects", id: { comment: "ID" }, comment: "案件", force: :cascade do |t|
    t.boolean "active", default: true, null: false, comment: "有効フラグ"
    t.string "code", null: false, comment: "案件コード"
    t.bigint "company_id", comment: "会社ID"
    t.datetime "created_at", null: false, comment: "作成日時"
    t.text "description", comment: "説明"
    t.string "name", null: false, comment: "案件名"
    t.string "public_id", null: false, comment: "公開ID"
    t.datetime "updated_at", null: false, comment: "更新日時"
    t.index ["code"], name: "index_projects_on_code", unique: true
    t.index ["company_id"], name: "index_projects_on_company_id"
    t.index ["public_id"], name: "index_projects_on_public_id", unique: true
  end

  create_table "publish_jobs", id: { comment: "ID" }, comment: "公開ジョブ", force: :cascade do |t|
    t.string "artifact_path", comment: "成果物パス"
    t.datetime "created_at", null: false, comment: "作成日時"
    t.text "log_message", comment: "ログメッセージ"
    t.string "public_id", null: false, comment: "公開ID"
    t.string "source_branch", null: false, comment: "ソースブランチ"
    t.string "source_commit_hash", null: false, comment: "ソースコミットハッシュ"
    t.string "source_repo", null: false, comment: "ソースリポジトリ"
    t.integer "status", default: 0, null: false, comment: "ステータス"
    t.datetime "updated_at", null: false, comment: "更新日時"
    t.index ["public_id"], name: "index_publish_jobs_on_public_id", unique: true
  end

  create_table "read_confirmations", id: { comment: "ID" }, comment: "既読確認", force: :cascade do |t|
    t.datetime "confirmed_at", null: false, comment: "確認日時"
    t.datetime "created_at", null: false, comment: "作成日時"
    t.bigint "document_id", null: false, comment: "文書ID"
    t.bigint "document_version_id", comment: "文書バージョンID"
    t.string "public_id", null: false, comment: "公開ID"
    t.datetime "updated_at", null: false, comment: "更新日時"
    t.bigint "user_id", null: false, comment: "利用者ID"
    t.index ["confirmed_at"], name: "index_read_confirmations_on_confirmed_at"
    t.index ["document_id"], name: "index_read_confirmations_on_document_id"
    t.index ["document_version_id"], name: "index_read_confirmations_on_document_version_id"
    t.index ["public_id"], name: "index_read_confirmations_on_public_id", unique: true
    t.index ["user_id", "document_id"], name: "index_read_confirmations_unique_user_document", unique: true
    t.index ["user_id"], name: "index_read_confirmations_on_user_id"
  end

  create_table "recurring_job_runs", force: :cascade do |t|
    t.string "active_job_id"
    t.json "args_json", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "enqueued_at"
    t.text "error_message"
    t.datetime "finished_at"
    t.string "job_class", null: false
    t.string "job_key", null: false
    t.json "metadata_json", default: {}, null: false
    t.string "public_id", null: false
    t.string "queue_name", default: "default", null: false
    t.bigint "recurring_job_schedule_id", null: false
    t.datetime "scheduled_at", null: false
    t.datetime "started_at"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["job_key", "scheduled_at"], name: "idx_recurring_job_runs_on_job_key_scheduled_at"
    t.index ["public_id"], name: "index_recurring_job_runs_on_public_id", unique: true
    t.index ["recurring_job_schedule_id"], name: "idx_recurring_job_runs_on_schedule"
    t.index ["status", "scheduled_at"], name: "idx_recurring_job_runs_on_status_scheduled_at"
  end

  create_table "recurring_job_schedules", force: :cascade do |t|
    t.boolean "allow_overlap", default: false, null: false
    t.json "args_json", default: {}, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.boolean "enabled", default: true, null: false
    t.integer "interval_seconds", default: 86400, null: false
    t.string "job_class", null: false
    t.string "job_key", null: false
    t.datetime "last_enqueued_at"
    t.text "last_error_message"
    t.datetime "last_finished_at"
    t.datetime "last_started_at"
    t.string "last_status"
    t.datetime "locked_at"
    t.string "locked_by"
    t.datetime "next_run_at", null: false
    t.string "public_id", null: false
    t.string "queue_name", default: "default", null: false
    t.datetime "run_requested_at"
    t.datetime "updated_at", null: false
    t.index ["enabled", "next_run_at"], name: "idx_recurring_job_schedules_on_enabled_next_run_at"
    t.index ["job_key"], name: "index_recurring_job_schedules_on_job_key", unique: true
    t.index ["public_id"], name: "index_recurring_job_schedules_on_public_id", unique: true
    t.index ["run_requested_at"], name: "index_recurring_job_schedules_on_run_requested_at"
  end

  create_table "solid_cable_messages", id: { comment: "ID" }, comment: "Solid Cableメッセージ", force: :cascade do |t|
    t.binary "channel", null: false, comment: "チャンネル"
    t.bigint "channel_hash", null: false, comment: "チャンネルハッシュ"
    t.datetime "created_at", null: false, comment: "作成日時"
    t.binary "payload", null: false, comment: "ペイロード"
    t.index ["channel"], name: "index_solid_cable_messages_on_channel"
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "table_preferences", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "default_flag", default: false, null: false
    t.string "name", default: "default", null: false
    t.string "scope_key"
    t.string "scope_type", default: "owner", null: false
    t.json "settings", null: false
    t.string "table_key", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["scope_type", "scope_key", "user_id", "table_key", "default_flag"], name: "idx_table_preferences_scope_table_default"
    t.index ["scope_type", "scope_key", "user_id", "table_key", "name"], name: "idx_table_preferences_scope_table_name", unique: true
    t.index ["user_id"], name: "index_table_preferences_on_user_id"
  end

  create_table "tree_view_states", id: { comment: "ID" }, comment: "ツリー表示状態", force: :cascade do |t|
    t.datetime "created_at", null: false, comment: "作成日時"
    t.json "expanded_keys", default: [], null: false, comment: "展開キー一覧"
    t.bigint "owner_id", null: false, comment: "所有者ID"
    t.string "owner_type", null: false, comment: "所有者種別"
    t.string "tree_instance_key", null: false, comment: "ツリーインスタンスキー"
    t.datetime "updated_at", null: false, comment: "更新日時"
    t.index ["owner_type", "owner_id", "tree_instance_key"], name: "idx_on_owner_type_owner_id_tree_instance_key_ebc312eed7", unique: true
    t.index ["owner_type", "owner_id"], name: "index_tree_view_states_on_owner"
  end

  create_table "user_consents", id: { comment: "ID" }, comment: "利用者同意", force: :cascade do |t|
    t.bigint "consent_term_id", null: false, comment: "同意規約ID"
    t.string "consent_term_version_label", null: false, comment: "同意規約バージョンラベル"
    t.datetime "consented_at", null: false, comment: "同意日時"
    t.datetime "created_at", null: false, comment: "作成日時"
    t.string "ip_address", comment: "IPアドレス"
    t.string "public_id", null: false, comment: "公開ID"
    t.bigint "target_id", comment: "対象ID"
    t.string "target_type", comment: "対象種別"
    t.datetime "updated_at", null: false, comment: "更新日時"
    t.text "user_agent", comment: "ユーザーエージェント"
    t.bigint "user_id", null: false, comment: "利用者ID"
    t.index ["consent_term_id"], name: "index_user_consents_on_consent_term_id"
    t.index ["consent_term_version_label"], name: "index_user_consents_on_consent_term_version_label"
    t.index ["consented_at"], name: "index_user_consents_on_consented_at"
    t.index ["public_id"], name: "index_user_consents_on_public_id", unique: true
    t.index ["target_type", "target_id"], name: "index_user_consents_on_target_type_and_target_id"
    t.index ["user_id", "consent_term_id", "target_type", "target_id", "consent_term_version_label"], name: "index_user_consents_unique_versioned_target", unique: true
    t.index ["user_id"], name: "index_user_consents_on_user_id"
  end

  create_table "users", id: { comment: "ID" }, comment: "利用者", force: :cascade do |t|
    t.boolean "active", default: true, null: false, comment: "有効フラグ"
    t.bigint "company_id", comment: "会社ID"
    t.datetime "created_at", null: false, comment: "作成日時"
    t.string "email_address", null: false, comment: "メールアドレス"
    t.datetime "last_login_at", comment: "最終ログイン日時"
    t.string "name", comment: "氏名"
    t.string "password_digest", null: false, comment: "パスワードダイジェスト"
    t.string "public_id", null: false, comment: "公開ID"
    t.datetime "updated_at", null: false, comment: "更新日時"
    t.integer "user_type", default: 0, null: false, comment: "利用者種別"
    t.index ["company_id"], name: "index_users_on_company_id"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["public_id"], name: "index_users_on_public_id", unique: true
    t.index ["user_type"], name: "index_users_on_user_type"
  end

  create_table "webhook_deliveries", id: { comment: "ID" }, comment: "Webhook配信", force: :cascade do |t|
    t.datetime "created_at", null: false, comment: "作成日時"
    t.text "error_message", comment: "エラーメッセージ"
    t.string "event_type", null: false, comment: "イベント種別"
    t.bigint "notification_event_id", null: false, comment: "通知イベントID"
    t.string "public_id", null: false, comment: "公開ID"
    t.text "request_body", null: false, comment: "リクエスト本文"
    t.text "response_body", comment: "レスポンス本文"
    t.integer "response_status", comment: "レスポンスステータス"
    t.datetime "sent_at", comment: "送信日時"
    t.integer "status", default: 0, null: false, comment: "ステータス"
    t.string "target_url", null: false, comment: "送信先URL"
    t.datetime "updated_at", null: false, comment: "更新日時"
    t.bigint "webhook_endpoint_id", null: false, comment: "WebhookエンドポイントID"
    t.index ["event_type"], name: "index_webhook_deliveries_on_event_type"
    t.index ["notification_event_id"], name: "index_webhook_deliveries_on_notification_event_id"
    t.index ["public_id"], name: "index_webhook_deliveries_on_public_id", unique: true
    t.index ["sent_at"], name: "index_webhook_deliveries_on_sent_at"
    t.index ["status"], name: "index_webhook_deliveries_on_status"
    t.index ["webhook_endpoint_id"], name: "index_webhook_deliveries_on_webhook_endpoint_id"
  end

  create_table "webhook_endpoints", id: { comment: "ID" }, comment: "Webhookエンドポイント", force: :cascade do |t|
    t.boolean "active", default: true, null: false, comment: "有効フラグ"
    t.datetime "created_at", null: false, comment: "作成日時"
    t.json "event_types", default: [], null: false, comment: "イベント種別一覧"
    t.json "headers_json", default: {}, null: false, comment: "ヘッダーJSON"
    t.string "name", null: false, comment: "名称"
    t.string "public_id", null: false, comment: "公開ID"
    t.string "secret_token", comment: "シークレットトークン"
    t.string "target_url", null: false, comment: "送信先URL"
    t.datetime "updated_at", null: false, comment: "更新日時"
    t.index ["active"], name: "index_webhook_endpoints_on_active"
    t.index ["name"], name: "index_webhook_endpoints_on_name"
    t.index ["public_id"], name: "index_webhook_endpoints_on_public_id", unique: true
  end

  add_foreign_key "access_logs", "companies"
  add_foreign_key "access_logs", "document_versions"
  add_foreign_key "access_logs", "documents"
  add_foreign_key "access_logs", "projects"
  add_foreign_key "access_logs", "users"
  add_foreign_key "access_requests", "users", column: "approver_id"
  add_foreign_key "access_requests", "users", column: "requester_id"
  add_foreign_key "bulk_edit_dry_runs", "projects"
  add_foreign_key "bulk_edit_dry_runs", "users", column: "confirmed_by_id"
  add_foreign_key "bulk_edit_dry_runs", "users", column: "created_by_id"
  add_foreign_key "document_approval_requests", "documents"
  add_foreign_key "document_approval_requests", "users", column: "acted_by_id"
  add_foreign_key "document_approval_requests", "users", column: "approver_id"
  add_foreign_key "document_approval_requests", "users", column: "requester_id"
  add_foreign_key "document_bookmarks", "documents"
  add_foreign_key "document_bookmarks", "users"
  add_foreign_key "document_catalog_items", "document_catalogs"
  add_foreign_key "document_catalog_items", "documents"
  add_foreign_key "document_catalogs", "projects"
  add_foreign_key "document_delivery_logs", "documents"
  add_foreign_key "document_delivery_logs", "projects"
  add_foreign_key "document_delivery_logs", "users", column: "sender_id"
  add_foreign_key "document_file_google_drive_preview_uploads", "document_files"
  add_foreign_key "document_file_microsoft_graph_preview_uploads", "document_files"
  add_foreign_key "document_file_microsoft_graph_preview_uploads", "microsoft_graph_connections"
  add_foreign_key "document_files", "document_versions"
  add_foreign_key "document_keywords", "documents"
  add_foreign_key "document_permissions", "companies"
  add_foreign_key "document_permissions", "documents"
  add_foreign_key "document_permissions", "users"
  add_foreign_key "document_relations", "documents", column: "source_document_id"
  add_foreign_key "document_relations", "documents", column: "target_document_id"
  add_foreign_key "document_review_comments", "document_review_comments", column: "parent_id"
  add_foreign_key "document_review_comments", "document_versions"
  add_foreign_key "document_review_comments", "documents"
  add_foreign_key "document_review_comments", "users", column: "author_id"
  add_foreign_key "document_review_comments", "users", column: "resolved_by_id"
  add_foreign_key "document_set_items", "document_sets"
  add_foreign_key "document_set_items", "document_versions"
  add_foreign_key "document_set_items", "documents"
  add_foreign_key "document_sets", "projects"
  add_foreign_key "document_sets", "users", column: "created_by_id"
  add_foreign_key "document_taggings", "document_tags"
  add_foreign_key "document_taggings", "documents"
  add_foreign_key "document_versions", "documents"
  add_foreign_key "document_versions", "users", column: "published_by_user_id"
  add_foreign_key "documents", "projects"
  add_foreign_key "documents", "users", column: "archived_by_user_id"
  add_foreign_key "external_folder_sync_items", "document_files"
  add_foreign_key "external_folder_sync_items", "document_versions"
  add_foreign_key "external_folder_sync_items", "documents"
  add_foreign_key "external_folder_sync_items", "external_folder_sync_sources"
  add_foreign_key "external_folder_sync_runs", "external_folder_sync_sources"
  add_foreign_key "external_folder_sync_sources", "projects"
  add_foreign_key "external_folder_sync_sources", "users", column: "created_by_id"
  add_foreign_key "external_folder_sync_subscriptions", "external_folder_sync_sources"
  add_foreign_key "external_folder_sync_webhook_events", "external_folder_sync_sources"
  add_foreign_key "external_folder_sync_webhook_events", "external_folder_sync_subscriptions"
  add_foreign_key "git_import_runs", "git_import_sources"
  add_foreign_key "git_import_sources", "projects"
  add_foreign_key "git_import_sources", "users", column: "created_by_id"
  add_foreign_key "import_dry_runs", "projects"
  add_foreign_key "import_dry_runs", "users", column: "confirmed_by_id"
  add_foreign_key "import_dry_runs", "users", column: "created_by_id"
  add_foreign_key "import_route_settings", "projects"
  add_foreign_key "microsoft_graph_connections", "projects"
  add_foreign_key "microsoft_graph_connections", "users", column: "created_by_id"
  add_foreign_key "notification_events", "document_versions"
  add_foreign_key "notification_events", "documents"
  add_foreign_key "notification_events", "projects"
  add_foreign_key "notification_events", "users", column: "actor_user_id"
  add_foreign_key "notification_receipts", "notification_events"
  add_foreign_key "notification_receipts", "users"
  add_foreign_key "project_consent_settings", "consent_terms"
  add_foreign_key "project_consent_settings", "projects"
  add_foreign_key "project_memberships", "projects"
  add_foreign_key "project_memberships", "users"
  add_foreign_key "projects", "companies"
  add_foreign_key "read_confirmations", "document_versions"
  add_foreign_key "read_confirmations", "documents"
  add_foreign_key "read_confirmations", "users"
  add_foreign_key "recurring_job_runs", "recurring_job_schedules"
  add_foreign_key "table_preferences", "users"
  add_foreign_key "user_consents", "consent_terms"
  add_foreign_key "user_consents", "users"
  add_foreign_key "users", "companies"
  add_foreign_key "webhook_deliveries", "notification_events"
  add_foreign_key "webhook_deliveries", "webhook_endpoints"
end
