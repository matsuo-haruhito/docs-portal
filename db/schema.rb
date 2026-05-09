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

ActiveRecord::Schema[8.1].define(version: 2026_05_09_090000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"

  create_table "access_logs", force: :cascade do |t|
    t.datetime "accessed_at", null: false
    t.integer "action_type", null: false
    t.bigint "company_id"
    t.datetime "created_at", null: false
    t.bigint "document_id"
    t.bigint "document_version_id"
    t.string "ip_address"
    t.bigint "project_id"
    t.string "public_id", null: false
    t.string "target_name"
    t.string "target_type", null: false
    t.datetime "updated_at", null: false
    t.text "user_agent"
    t.bigint "user_id"
    t.index ["company_id"], name: "index_access_logs_on_company_id"
    t.index ["document_id"], name: "index_access_logs_on_document_id"
    t.index ["document_version_id"], name: "index_access_logs_on_document_version_id"
    t.index ["project_id"], name: "index_access_logs_on_project_id"
    t.index ["public_id"], name: "index_access_logs_on_public_id", unique: true
    t.index ["user_id"], name: "index_access_logs_on_user_id"
  end

  create_table "access_requests", force: :cascade do |t|
    t.datetime "approved_at"
    t.bigint "approver_id"
    t.datetime "cancelled_at"
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.string "public_id", null: false
    t.text "reason", null: false
    t.datetime "rejected_at"
    t.text "rejection_reason"
    t.bigint "requestable_id", null: false
    t.string "requestable_type", null: false
    t.integer "requested_access_level", default: 0, null: false
    t.bigint "requester_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
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

  create_table "bulk_edit_dry_runs", force: :cascade do |t|
    t.datetime "confirmed_at"
    t.bigint "confirmed_by_id"
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.json "errors_json", default: [], null: false
    t.datetime "expires_at"
    t.integer "operation_type", default: 0, null: false
    t.json "params_json", default: {}, null: false
    t.bigint "project_id"
    t.string "public_id", null: false
    t.json "result_json", default: {}, null: false
    t.integer "status", default: 0, null: false
    t.json "summary_json", default: {}, null: false
    t.json "target_document_ids", default: [], null: false
    t.datetime "updated_at", null: false
    t.json "warnings_json", default: [], null: false
    t.index ["confirmed_by_id"], name: "index_bulk_edit_dry_runs_on_confirmed_by_id"
    t.index ["created_by_id"], name: "index_bulk_edit_dry_runs_on_created_by_id"
    t.index ["operation_type"], name: "index_bulk_edit_dry_runs_on_operation_type"
    t.index ["project_id"], name: "index_bulk_edit_dry_runs_on_project_id"
    t.index ["public_id"], name: "index_bulk_edit_dry_runs_on_public_id", unique: true
    t.index ["status"], name: "index_bulk_edit_dry_runs_on_status"
  end

  create_table "companies", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "domain", null: false
    t.string "name"
    t.string "public_id", null: false
    t.datetime "updated_at", null: false
    t.index ["domain"], name: "index_companies_on_domain", unique: true
    t.index ["public_id"], name: "index_companies_on_public_id", unique: true
  end

  create_table "consent_terms", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.text "body", null: false
    t.integer "consent_scope", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "public_id", null: false
    t.integer "requirement_timing", default: 0, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.string "version_label", null: false
    t.index ["active"], name: "index_consent_terms_on_active"
    t.index ["consent_scope"], name: "index_consent_terms_on_consent_scope"
    t.index ["public_id"], name: "index_consent_terms_on_public_id", unique: true
    t.index ["requirement_timing"], name: "index_consent_terms_on_requirement_timing"
    t.index ["title", "version_label"], name: "index_consent_terms_on_title_and_version_label", unique: true
  end

  create_table "document_approval_requests", force: :cascade do |t|
    t.bigint "acted_by_id"
    t.datetime "approved_at"
    t.bigint "approver_id"
    t.text "body"
    t.datetime "cancelled_at"
    t.datetime "created_at", null: false
    t.bigint "document_id", null: false
    t.string "public_id", null: false
    t.bigint "requester_id", null: false
    t.integer "status", default: 0, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["acted_by_id"], name: "index_document_approval_requests_on_acted_by_id"
    t.index ["approved_at"], name: "index_document_approval_requests_on_approved_at"
    t.index ["approver_id"], name: "index_document_approval_requests_on_approver_id"
    t.index ["cancelled_at"], name: "index_document_approval_requests_on_cancelled_at"
    t.index ["document_id"], name: "index_document_approval_requests_on_document_id"
    t.index ["public_id"], name: "index_document_approval_requests_on_public_id", unique: true
    t.index ["requester_id"], name: "index_document_approval_requests_on_requester_id"
    t.index ["status"], name: "index_document_approval_requests_on_status"
  end

  create_table "document_bookmarks", force: :cascade do |t|
    t.integer "bookmark_type", default: 0, null: false
    t.datetime "created_at", null: false
    t.bigint "document_id", null: false
    t.string "public_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["document_id"], name: "index_document_bookmarks_on_document_id"
    t.index ["public_id"], name: "index_document_bookmarks_on_public_id", unique: true
    t.index ["user_id", "document_id", "bookmark_type"], name: "index_document_bookmarks_unique_user_document_type", unique: true
    t.index ["user_id"], name: "index_document_bookmarks_on_user_id"
  end

  create_table "document_catalog_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "document_catalog_id", null: false
    t.bigint "document_id", null: false
    t.text "note"
    t.integer "sort_order", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["document_catalog_id", "document_id"], name: "index_document_catalog_items_unique_catalog_document", unique: true
    t.index ["document_catalog_id"], name: "index_document_catalog_items_on_document_catalog_id"
    t.index ["document_id"], name: "index_document_catalog_items_on_document_id"
    t.index ["sort_order"], name: "index_document_catalog_items_on_sort_order"
  end

  create_table "document_catalogs", force: :cascade do |t|
    t.integer "audience_type", default: 0, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.bigint "project_id", null: false
    t.string "public_id", null: false
    t.integer "sort_order", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "visibility_policy", default: 0, null: false
    t.index ["audience_type"], name: "index_document_catalogs_on_audience_type"
    t.index ["project_id", "name"], name: "index_document_catalogs_on_project_id_and_name", unique: true
    t.index ["project_id"], name: "index_document_catalogs_on_project_id"
    t.index ["public_id"], name: "index_document_catalogs_on_public_id", unique: true
    t.index ["sort_order"], name: "index_document_catalogs_on_sort_order"
    t.index ["visibility_policy"], name: "index_document_catalogs_on_visibility_policy"
  end

  create_table "document_delivery_logs", force: :cascade do |t|
    t.text "bcc_addresses"
    t.text "body", null: false
    t.text "cc_addresses"
    t.datetime "created_at", null: false
    t.integer "delivery_type", default: 0, null: false
    t.bigint "document_id"
    t.bigint "document_set_id"
    t.text "error_message"
    t.bigint "project_id", null: false
    t.string "public_id", null: false
    t.bigint "sender_id", null: false
    t.datetime "sent_at"
    t.integer "status", default: 0, null: false
    t.string "subject", null: false
    t.text "to_addresses", null: false
    t.datetime "updated_at", null: false
    t.index ["delivery_type"], name: "index_document_delivery_logs_on_delivery_type"
    t.index ["document_id"], name: "index_document_delivery_logs_on_document_id"
    t.index ["document_set_id"], name: "index_document_delivery_logs_on_document_set_id"
    t.index ["project_id"], name: "index_document_delivery_logs_on_project_id"
    t.index ["public_id"], name: "index_document_delivery_logs_on_public_id", unique: true
    t.index ["sender_id"], name: "index_document_delivery_logs_on_sender_id"
    t.index ["sent_at"], name: "index_document_delivery_logs_on_sent_at"
    t.index ["status"], name: "index_document_delivery_logs_on_status"
  end

  create_table "document_files", force: :cascade do |t|
    t.string "content_type", null: false
    t.datetime "created_at", null: false
    t.bigint "document_version_id", null: false
    t.string "file_name", null: false
    t.bigint "file_size", default: 0, null: false
    t.string "public_id", null: false
    t.text "scan_error_message"
    t.integer "scan_status", default: 0, null: false
    t.datetime "scanned_at"
    t.text "search_text"
    t.integer "sort_order", default: 0, null: false
    t.string "storage_key", null: false
    t.datetime "updated_at", null: false
    t.index ["document_version_id"], name: "index_document_files_on_document_version_id"
    t.index ["file_name"], name: "index_document_files_on_file_name_trigram", opclass: :gin_trgm_ops, using: :gin
    t.index ["public_id"], name: "index_document_files_on_public_id", unique: true
    t.index ["scan_status"], name: "index_document_files_on_scan_status"
    t.index ["search_text"], name: "index_document_files_on_search_text_trigram", opclass: :gin_trgm_ops, using: :gin
    t.index ["storage_key"], name: "index_document_files_on_storage_key", unique: true
  end

  create_table "document_keywords", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "document_id", null: false
    t.string "keyword", null: false
    t.string "normalized_keyword", null: false
    t.string "public_id", null: false
    t.integer "sort_order", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["document_id", "normalized_keyword"], name: "index_document_keywords_on_document_id_and_normalized_keyword", unique: true
    t.index ["document_id"], name: "index_document_keywords_on_document_id"
    t.index ["keyword"], name: "index_document_keywords_on_keyword_trigram", opclass: :gin_trgm_ops, using: :gin
    t.index ["normalized_keyword"], name: "index_document_keywords_on_normalized_keyword"
    t.index ["normalized_keyword"], name: "index_document_keywords_on_normalized_keyword_trigram", opclass: :gin_trgm_ops, using: :gin
    t.index ["public_id"], name: "index_document_keywords_on_public_id", unique: true
  end

  create_table "document_permissions", force: :cascade do |t|
    t.integer "access_level", default: 0, null: false
    t.bigint "company_id"
    t.datetime "created_at", null: false
    t.bigint "document_id", null: false
    t.string "public_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["company_id"], name: "index_document_permissions_on_company_id"
    t.index ["document_id"], name: "index_document_permissions_on_document_id"
    t.index ["public_id"], name: "index_document_permissions_on_public_id", unique: true
    t.index ["user_id"], name: "index_document_permissions_on_user_id"
  end

  create_table "document_relations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "note"
    t.string "public_id", null: false
    t.integer "relation_type", default: 0, null: false
    t.integer "sort_order", default: 0, null: false
    t.bigint "source_document_id", null: false
    t.bigint "target_document_id", null: false
    t.datetime "updated_at", null: false
    t.index ["public_id"], name: "index_document_relations_on_public_id", unique: true
    t.index ["source_document_id", "target_document_id", "relation_type"], name: "index_document_relations_unique_relation", unique: true
    t.index ["source_document_id"], name: "index_document_relations_on_source_document_id"
    t.index ["target_document_id"], name: "index_document_relations_on_target_document_id"
  end

  create_table "document_review_comments", force: :cascade do |t|
    t.bigint "author_id", null: false
    t.text "body", null: false
    t.integer "comment_type", default: 0, null: false
    t.datetime "created_at", null: false
    t.bigint "document_id", null: false
    t.bigint "document_version_id"
    t.boolean "internal_only", default: true, null: false
    t.bigint "parent_id"
    t.string "public_id", null: false
    t.datetime "resolved_at"
    t.bigint "resolved_by_id"
    t.string "source_path"
    t.integer "status", default: 0, null: false
    t.string "text_anchor_label"
    t.string "text_anchor_path"
    t.string "text_anchor_type"
    t.integer "text_line_end"
    t.integer "text_line_start"
    t.datetime "updated_at", null: false
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

  create_table "document_set_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "document_id", null: false
    t.bigint "document_set_id", null: false
    t.bigint "document_version_id"
    t.text "note"
    t.integer "sort_order", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["document_id"], name: "index_document_set_items_on_document_id"
    t.index ["document_set_id", "document_id"], name: "index_document_set_items_on_document_set_id_and_document_id", unique: true
    t.index ["document_set_id"], name: "index_document_set_items_on_document_set_id"
    t.index ["document_version_id"], name: "index_document_set_items_on_document_version_id"
    t.index ["sort_order"], name: "index_document_set_items_on_sort_order"
  end

  create_table "document_sets", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.text "description"
    t.string "name", null: false
    t.bigint "project_id", null: false
    t.string "public_id", null: false
    t.integer "set_type", default: 0, null: false
    t.integer "sort_order", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "visibility_policy", default: 0, null: false
    t.index ["created_by_id"], name: "index_document_sets_on_created_by_id"
    t.index ["project_id", "name"], name: "index_document_sets_on_project_id_and_name", unique: true
    t.index ["project_id"], name: "index_document_sets_on_project_id"
    t.index ["public_id"], name: "index_document_sets_on_public_id", unique: true
    t.index ["set_type"], name: "index_document_sets_on_set_type"
    t.index ["sort_order"], name: "index_document_sets_on_sort_order"
    t.index ["visibility_policy"], name: "index_document_sets_on_visibility_policy"
  end

  create_table "document_taggings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "document_id", null: false
    t.bigint "document_tag_id", null: false
    t.integer "sort_order", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["document_id", "document_tag_id"], name: "index_document_taggings_on_document_id_and_document_tag_id", unique: true
    t.index ["document_id"], name: "index_document_taggings_on_document_id"
    t.index ["document_tag_id"], name: "index_document_taggings_on_document_tag_id"
  end

  create_table "document_tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "normalized_name", null: false
    t.string "public_id", null: false
    t.datetime "updated_at", null: false
    t.index ["normalized_name"], name: "index_document_tags_on_normalized_name", unique: true
    t.index ["public_id"], name: "index_document_tags_on_public_id", unique: true
  end

  create_table "document_versions", force: :cascade do |t|
    t.text "changelog_summary"
    t.datetime "created_at", null: false
    t.bigint "document_id", null: false
    t.string "markdown_entry_path"
    t.text "notes"
    t.string "pdf_snapshot_path"
    t.string "public_id", null: false
    t.datetime "published_at"
    t.bigint "published_by_user_id"
    t.datetime "published_from"
    t.datetime "published_until"
    t.text "search_body_text"
    t.string "site_build_path"
    t.string "snapshot_kind"
    t.string "source_basename"
    t.string "source_commit_hash", null: false
    t.string "source_directory"
    t.string "source_extension"
    t.string "source_file_name"
    t.string "source_relative_path"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.string "version_label", null: false
    t.index ["document_id", "version_label"], name: "index_document_versions_on_document_id_and_version_label", unique: true
    t.index ["document_id"], name: "index_document_versions_on_document_id"
    t.index ["public_id"], name: "index_document_versions_on_public_id", unique: true
    t.index ["published_by_user_id"], name: "index_document_versions_on_published_by_user_id"
    t.index ["published_from"], name: "index_document_versions_on_published_from"
    t.index ["published_until"], name: "index_document_versions_on_published_until"
    t.index ["search_body_text"], name: "index_document_versions_on_search_body_text_trigram", opclass: :gin_trgm_ops, using: :gin
    t.index ["snapshot_kind"], name: "index_document_versions_on_snapshot_kind"
    t.index ["source_directory"], name: "index_document_versions_on_source_directory"
    t.index ["source_directory"], name: "index_document_versions_on_source_directory_trigram", opclass: :gin_trgm_ops, using: :gin
    t.index ["source_file_name"], name: "index_document_versions_on_source_file_name_trigram", opclass: :gin_trgm_ops, using: :gin
    t.index ["source_relative_path"], name: "index_document_versions_on_source_relative_path"
    t.index ["source_relative_path"], name: "index_document_versions_on_source_relative_path_trigram", opclass: :gin_trgm_ops, using: :gin
    t.index ["version_label"], name: "index_document_versions_on_version_label_trigram", opclass: :gin_trgm_ops, using: :gin
  end

  create_table "documents", force: :cascade do |t|
    t.datetime "archived_at"
    t.bigint "archived_by_user_id"
    t.integer "category", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "discard_candidate_at"
    t.integer "document_kind", default: 0, null: false
    t.integer "importance_level", default: 2, null: false
    t.bigint "latest_version_id"
    t.bigint "project_id", null: false
    t.string "public_id", null: false
    t.text "reading_note"
    t.integer "recommended_sort_order", default: 0, null: false
    t.datetime "retention_until"
    t.string "slug", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.integer "visibility_policy", default: 0, null: false
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

  create_table "git_import_runs", force: :cascade do |t|
    t.string "branch", null: false
    t.string "commit_sha"
    t.datetime "created_at", null: false
    t.text "error_message"
    t.datetime "finished_at"
    t.bigint "git_import_source_id"
    t.integer "import_mode", default: 0, null: false
    t.integer "provider", default: 0, null: false
    t.string "public_id", null: false
    t.string "repository_full_name", null: false
    t.string "source_path", null: false
    t.datetime "started_at"
    t.integer "status", default: 0, null: false
    t.json "summary_json", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index ["commit_sha"], name: "index_git_import_runs_on_commit_sha"
    t.index ["git_import_source_id"], name: "index_git_import_runs_on_git_import_source_id"
    t.index ["public_id"], name: "index_git_import_runs_on_public_id", unique: true
    t.index ["status"], name: "index_git_import_runs_on_status"
  end

  create_table "git_import_sources", force: :cascade do |t|
    t.integer "auth_type", default: 0, null: false
    t.string "branch", default: "main", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.string "credential_ref"
    t.text "credential_secret"
    t.boolean "enabled", default: true, null: false
    t.string "installation_id"
    t.datetime "last_synced_at"
    t.string "last_synced_commit_sha"
    t.string "organization_name"
    t.bigint "project_id", null: false
    t.integer "provider", default: 0, null: false
    t.string "public_id", null: false
    t.string "repository_full_name", null: false
    t.string "source_path", default: "docs", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_git_import_sources_on_created_by_id"
    t.index ["enabled"], name: "index_git_import_sources_on_enabled"
    t.index ["project_id", "repository_full_name", "branch", "source_path"], name: "index_git_import_sources_unique_target", unique: true
    t.index ["project_id"], name: "index_git_import_sources_on_project_id"
    t.index ["public_id"], name: "index_git_import_sources_on_public_id", unique: true
    t.index ["repository_full_name"], name: "index_git_import_sources_on_repository_full_name"
  end

  create_table "import_dry_runs", force: :cascade do |t|
    t.datetime "confirmed_at"
    t.bigint "confirmed_by_id"
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.json "errors_json", default: [], null: false
    t.datetime "expires_at"
    t.integer "import_mode", default: 0, null: false
    t.bigint "project_id"
    t.string "public_id", null: false
    t.json "result_json", default: {}, null: false
    t.string "source_commit_hash"
    t.integer "status", default: 0, null: false
    t.json "summary_json", default: {}, null: false
    t.datetime "updated_at", null: false
    t.json "warnings_json", default: [], null: false
    t.index ["confirmed_by_id"], name: "index_import_dry_runs_on_confirmed_by_id"
    t.index ["created_by_id"], name: "index_import_dry_runs_on_created_by_id"
    t.index ["import_mode"], name: "index_import_dry_runs_on_import_mode"
    t.index ["project_id"], name: "index_import_dry_runs_on_project_id"
    t.index ["public_id"], name: "index_import_dry_runs_on_public_id", unique: true
    t.index ["status"], name: "index_import_dry_runs_on_status"
  end

  create_table "notification_events", force: :cascade do |t|
    t.bigint "actor_user_id"
    t.text "body"
    t.datetime "created_at", null: false
    t.bigint "document_id"
    t.bigint "document_version_id"
    t.integer "event_type", null: false
    t.datetime "occurred_at", null: false
    t.bigint "project_id"
    t.string "public_id", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_user_id"], name: "index_notification_events_on_actor_user_id"
    t.index ["document_id"], name: "index_notification_events_on_document_id"
    t.index ["document_version_id"], name: "index_notification_events_on_document_version_id"
    t.index ["event_type"], name: "index_notification_events_on_event_type"
    t.index ["occurred_at"], name: "index_notification_events_on_occurred_at"
    t.index ["project_id"], name: "index_notification_events_on_project_id"
    t.index ["public_id"], name: "index_notification_events_on_public_id", unique: true
  end

  create_table "notification_receipts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "notification_event_id", null: false
    t.string "public_id", null: false
    t.datetime "read_at"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["notification_event_id", "user_id"], name: "index_notification_receipts_unique_event_user", unique: true
    t.index ["notification_event_id"], name: "index_notification_receipts_on_notification_event_id"
    t.index ["public_id"], name: "index_notification_receipts_on_public_id", unique: true
    t.index ["read_at"], name: "index_notification_receipts_on_read_at"
    t.index ["user_id"], name: "index_notification_receipts_on_user_id"
  end

  create_table "project_consent_settings", force: :cascade do |t|
    t.bigint "consent_term_id", null: false
    t.datetime "created_at", null: false
    t.boolean "enabled", default: true, null: false
    t.bigint "project_id", null: false
    t.string "public_id", null: false
    t.integer "required_on", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["consent_term_id"], name: "index_project_consent_settings_on_consent_term_id"
    t.index ["enabled"], name: "index_project_consent_settings_on_enabled"
    t.index ["project_id", "consent_term_id", "required_on"], name: "index_project_consent_settings_unique_requirement", unique: true
    t.index ["project_id"], name: "index_project_consent_settings_on_project_id"
    t.index ["public_id"], name: "index_project_consent_settings_on_public_id", unique: true
    t.index ["required_on"], name: "index_project_consent_settings_on_required_on"
  end

  create_table "project_memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "project_id", null: false
    t.string "public_id", null: false
    t.integer "role", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["project_id", "user_id"], name: "index_project_memberships_on_project_id_and_user_id", unique: true
    t.index ["project_id"], name: "index_project_memberships_on_project_id"
    t.index ["public_id"], name: "index_project_memberships_on_public_id", unique: true
    t.index ["user_id"], name: "index_project_memberships_on_user_id"
  end

  create_table "projects", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.string "public_id", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_projects_on_code", unique: true
    t.index ["public_id"], name: "index_projects_on_public_id", unique: true
  end

  create_table "publish_jobs", force: :cascade do |t|
    t.string "artifact_path"
    t.datetime "created_at", null: false
    t.text "log_message"
    t.string "public_id", null: false
    t.string "source_branch", null: false
    t.string "source_commit_hash", null: false
    t.string "source_repo", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["public_id"], name: "index_publish_jobs_on_public_id", unique: true
  end

  create_table "read_confirmations", force: :cascade do |t|
    t.datetime "confirmed_at", null: false
    t.datetime "created_at", null: false
    t.bigint "document_id", null: false
    t.bigint "document_version_id"
    t.string "public_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["confirmed_at"], name: "index_read_confirmations_on_confirmed_at"
    t.index ["document_id"], name: "index_read_confirmations_on_document_id"
    t.index ["document_version_id"], name: "index_read_confirmations_on_document_version_id"
    t.index ["public_id"], name: "index_read_confirmations_on_public_id", unique: true
    t.index ["user_id", "document_id"], name: "index_read_confirmations_unique_user_document", unique: true
    t.index ["user_id"], name: "index_read_confirmations_on_user_id"
  end

  create_table "user_consents", force: :cascade do |t|
    t.bigint "consent_term_id", null: false
    t.string "consent_term_version_label", null: false
    t.datetime "consented_at", null: false
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.string "public_id", null: false
    t.bigint "target_id"
    t.string "target_type"
    t.datetime "updated_at", null: false
    t.text "user_agent"
    t.bigint "user_id", null: false
    t.index ["consent_term_id"], name: "index_user_consents_on_consent_term_id"
    t.index ["consent_term_version_label"], name: "index_user_consents_on_consent_term_version_label"
    t.index ["consented_at"], name: "index_user_consents_on_consented_at"
    t.index ["public_id"], name: "index_user_consents_on_public_id", unique: true
    t.index ["target_type", "target_id"], name: "index_user_consents_on_target_type_and_target_id"
    t.index ["user_id", "consent_term_id", "target_type", "target_id", "consent_term_version_label"], name: "index_user_consents_unique_versioned_target", unique: true
    t.index ["user_id"], name: "index_user_consents_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.bigint "company_id"
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.datetime "last_login_at"
    t.string "name"
    t.string "password_digest", null: false
    t.string "public_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_type", default: 0, null: false
    t.index ["company_id"], name: "index_users_on_company_id"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["public_id"], name: "index_users_on_public_id", unique: true
    t.index ["user_type"], name: "index_users_on_user_type"
  end

  create_table "webhook_deliveries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error_message"
    t.string "event_type", null: false
    t.bigint "notification_event_id", null: false
    t.string "public_id", null: false
    t.text "request_body", null: false
    t.text "response_body"
    t.integer "response_status"
    t.datetime "sent_at"
    t.integer "status", default: 0, null: false
    t.string "target_url", null: false
    t.datetime "updated_at", null: false
    t.bigint "webhook_endpoint_id", null: false
    t.index ["event_type"], name: "index_webhook_deliveries_on_event_type"
    t.index ["notification_event_id"], name: "index_webhook_deliveries_on_notification_event_id"
    t.index ["public_id"], name: "index_webhook_deliveries_on_public_id", unique: true
    t.index ["sent_at"], name: "index_webhook_deliveries_on_sent_at"
    t.index ["status"], name: "index_webhook_deliveries_on_status"
    t.index ["webhook_endpoint_id"], name: "index_webhook_deliveries_on_webhook_endpoint_id"
  end

  create_table "webhook_endpoints", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.json "event_types", default: [], null: false
    t.json "headers_json", default: {}, null: false
    t.string "name", null: false
    t.string "public_id", null: false
    t.string "secret_token"
    t.string "target_url", null: false
    t.datetime "updated_at", null: false
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
  add_foreign_key "document_delivery_logs", "document_sets"
  add_foreign_key "document_delivery_logs", "documents"
  add_foreign_key "document_delivery_logs", "projects"
  add_foreign_key "document_delivery_logs", "users", column: "sender_id"
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
  add_foreign_key "git_import_runs", "git_import_sources"
  add_foreign_key "git_import_sources", "projects"
  add_foreign_key "git_import_sources", "users", column: "created_by_id"
  add_foreign_key "import_dry_runs", "projects"
  add_foreign_key "import_dry_runs", "users", column: "confirmed_by_id"
  add_foreign_key "import_dry_runs", "users", column: "created_by_id"
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
  add_foreign_key "read_confirmations", "document_versions"
  add_foreign_key "read_confirmations", "documents"
  add_foreign_key "read_confirmations", "users"
  add_foreign_key "user_consents", "consent_terms"
  add_foreign_key "user_consents", "users"
  add_foreign_key "users", "companies"
  add_foreign_key "webhook_deliveries", "notification_events"
  add_foreign_key "webhook_deliveries", "webhook_endpoints"
end
