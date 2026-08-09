# frozen_string_literal: true

class AddOauthMcpAndDocumentSourceAuthority < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :source_authority, :integer, null: false, default: 0,
      comment: "正本区分（docs-portal/GitHub/sales-mgt/外部フォルダ）"
    reversible do |direction|
      direction.up do
        safety_assured { backfill_document_source_authorities }
      end
    end

    create_table :oauth_applications, comment: "OAuthクライアント" do |t|
      t.string :name, null: false, comment: "クライアント名称"
      t.string :uid, null: false, comment: "クライアントID"
      t.string :secret, null: false, comment: "クライアントシークレットダイジェスト"
      t.text :redirect_uri, null: false, comment: "リダイレクトURI"
      t.string :scopes, null: false, default: "documents:read", comment: "許可スコープ"
      t.boolean :confidential, null: false, default: true, comment: "機密クライアントフラグ"
      t.timestamps
      t.index :uid, unique: true
    end

    create_table :oauth_access_grants, comment: "OAuth認可コード" do |t|
      t.references :resource_owner, null: false, comment: "認可利用者ID"
      t.references :application, null: false, comment: "OAuthクライアントID"
      t.string :token, null: false, comment: "認可コードダイジェスト"
      t.integer :expires_in, null: false, comment: "有効期間秒数"
      t.text :redirect_uri, null: false, comment: "リダイレクトURI"
      t.string :scopes, null: false, default: "", comment: "認可スコープ"
      t.datetime :created_at, null: false, comment: "作成日時"
      t.datetime :revoked_at, comment: "失効日時"
      t.string :code_challenge, comment: "PKCEコードチャレンジ"
      t.string :code_challenge_method, comment: "PKCE方式"
      t.index :token, unique: true
    end

    create_table :oauth_access_tokens, comment: "OAuthアクセストークン" do |t|
      t.references :resource_owner, null: false, index: false, comment: "トークン所有利用者ID"
      t.references :application, null: false, index: false, comment: "OAuthクライアントID"
      t.string :token, null: false, comment: "アクセストークンダイジェスト"
      t.string :refresh_token, comment: "リフレッシュトークンダイジェスト"
      t.integer :expires_in, comment: "有効期間秒数"
      t.string :scopes, null: false, default: "", comment: "認可スコープ"
      t.datetime :created_at, null: false, comment: "作成日時"
      t.datetime :revoked_at, comment: "失効日時"
      t.string :previous_refresh_token, null: false, default: "", comment: "前回リフレッシュトークンダイジェスト"
      t.index :token, unique: true
      t.index :refresh_token, unique: true
      t.index :resource_owner_id
      t.index [:application_id, :resource_owner_id], name: "idx_oauth_tokens_app_owner"
    end

    create_table :mcp_mutation_receipts, comment: "MCP更新受領台帳" do |t|
      t.string :public_id, null: false, comment: "公開ID"
      t.references :oauth_application, null: false, comment: "OAuthクライアントID"
      t.references :user, null: false, comment: "実行利用者ID"
      t.references :document, comment: "対象文書ID"
      t.references :document_version, comment: "対象文書版ID"
      t.string :operation, null: false, comment: "更新操作"
      t.string :idempotency_key_digest, null: false, comment: "冪等キーのダイジェスト"
      t.string :request_digest, null: false, comment: "リクエストダイジェスト"
      t.jsonb :before_json, null: false, default: {}, comment: "更新前情報"
      t.jsonb :after_json, null: false, default: {}, comment: "更新後情報"
      t.jsonb :response_json, null: false, default: {}, comment: "確定レスポンス"
      t.datetime :completed_at, null: false, comment: "処理確定日時"
      t.timestamps
      t.index :public_id, unique: true
      t.index [:oauth_application_id, :user_id, :operation, :idempotency_key_digest],
        unique: true, name: "idx_mcp_receipts_idempotency"
    end

    add_foreign_key :oauth_access_grants, :users,
      column: :resource_owner_id, on_delete: :cascade, validate: false
    add_foreign_key :oauth_access_grants, :oauth_applications,
      column: :application_id, on_delete: :cascade, validate: false
    add_foreign_key :oauth_access_tokens, :users,
      column: :resource_owner_id, on_delete: :cascade, validate: false
    add_foreign_key :oauth_access_tokens, :oauth_applications,
      column: :application_id, on_delete: :cascade, validate: false
  end

  private

  def backfill_document_source_authorities
    execute <<~SQL.squish
      UPDATE documents
      SET source_authority = 1
      WHERE EXISTS (
        SELECT 1 FROM document_versions
        WHERE document_versions.document_id = documents.id
          AND document_versions.snapshot_kind = 'git_import'
      )
    SQL

    execute <<~SQL.squish
      UPDATE documents
      SET source_authority = 3
      WHERE EXISTS (
        SELECT 1 FROM external_folder_sync_items
        WHERE external_folder_sync_items.document_id = documents.id
      )
    SQL

    execute <<~SQL.squish
      UPDATE documents
      SET source_authority = 2
      WHERE EXISTS (
        SELECT 1 FROM external_master_sync_mappings
        WHERE external_master_sync_mappings.sync_target_type = 'Document'
          AND external_master_sync_mappings.sync_target_id = documents.id
          AND external_master_sync_mappings.source_system = 'sales-mgt'
      )
    SQL
  end
end
