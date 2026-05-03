# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends
# to be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_05_03_150000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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

  create_table "companies", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "public_id", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_companies_on_code", unique: true
    t.index ["public_id"], name: "index_companies_on_public_id", unique: true
  end

  create_table "document_files", force: :cascade do |t|
    t.string "content_type", null: false
    t.datetime "created_at", null: false
    t.bigint "document_version_id", null: false
    t.string "file_name", null: false
    t.bigint "file_size", default: 0, null: false
    t.string "public_id", null: false
    t.text "search_text"
    t.integer "sort_order", default: 0, null: false
    t.string "storage_key", null: false
    t.datetime "updated_at", null: false
    t.index ["document_version_id"], name: "index_document_files_on_document_version_id"
    t.index ["public_id"], name: "index_document_files_on_public_id", unique: true
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
    t.index ["normalized_keyword"], name: "index_document_keywords_on_normalized_keyword"
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
    t.index ["snapshot_kind"], name: "index_document_versions_on_snapshot_kind"
    t.index ["source_directory"], name: "index_document_versions_on_source_directory"
    t.index ["source_relative_path"], name: "index_document_versions_on_source_relative_path"
  end

  create_table "documents", force: :cascade do |t|
    t.integer "category", default: 0, null: false
    t.datetime "created_at", null: false
    t.integer "document_kind", default: 0, null: false
    t.bigint "latest_version_id"
    t.bigint "project_id", null: false
    t.string "public_id", null: false
    t.string "slug", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.integer "visibility_policy", default: 0, null: false
    t.index ["latest_version_id"], name: "index_documents_on_latest_version_id"
    t.index ["project_id", "slug"], name: "index_documents_on_project_id_and_slug", unique: true
    t.index ["project_id"], name: "index_documents_on_project_id"
    t.index ["public_id"], name: "index_documents_on_public_id", unique: true
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

  create_table "users", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.bigint "company_id"
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.datetime "last_login_at"
    t.string "name", default: "", null: false
    t.string "password_digest", null: false
    t.string "public_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_type", default: 0, null: false
    t.index ["company_id"], name: "index_users_on_company_id"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["public_id"], name: "index_users_on_public_id", unique: true
    t.index ["user_type"], name: "index_users_on_user_type"
  end

  add_foreign_key "access_logs", "companies"
  add_foreign_key "access_logs", "document_versions"
  add_foreign_key "access_logs", "documents"
  add_foreign_key "access_logs", "projects"
  add_foreign_key "access_logs", "users"
  add_foreign_key "document_files", "document_versions"
  add_foreign_key "document_keywords", "documents"
  add_foreign_key "document_permissions", "companies"
  add_foreign_key "document_permissions", "documents"
  add_foreign_key "document_permissions", "users"
  add_foreign_key "document_relations", "documents", column: "source_document_id"
  add_foreign_key "document_relations", "documents", column: "target_document_id"
  add_foreign_key "document_taggings", "document_tags"
  add_foreign_key "document_taggings", "documents"
  add_foreign_key "document_versions", "documents"
  add_foreign_key "document_versions", "users", column: "published_by_user_id"
  add_foreign_key "documents", "projects"
  add_foreign_key "project_memberships", "projects"
  add_foreign_key "project_memberships", "users"
  add_foreign_key "users", "companies"
end
