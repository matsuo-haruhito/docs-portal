class CreateMasterSyncTables < ActiveRecord::Migration[8.1]
  def change
    create_table :external_master_sync_mappings, comment: "外部マスタ同期マッピング" do |t|
      t.string :public_id, null: false, comment: "公開ID"
      t.string :source_system, null: false, comment: "同期元システム"
      t.string :resource_type, null: false, comment: "同期リソース種別"
      t.string :external_id, null: false, comment: "同期元外部ID"
      t.string :sync_target_type, comment: "同期先種別"
      t.bigint :sync_target_id, comment: "同期先ID"
      t.datetime :source_updated_at, null: false, comment: "同期元更新日時"
      t.jsonb :source_attributes, null: false, default: {}, comment: "同期元属性スナップショット"
      t.timestamps

      t.index :public_id, unique: true
      t.index %i[source_system resource_type external_id],
        unique: true,
        name: "idx_external_master_sync_mappings_identity"
      t.index %i[sync_target_type sync_target_id],
        name: "idx_external_master_sync_mappings_target"
      t.check_constraint "resource_type IN ('company', 'project', 'document')",
        name: "external_master_sync_mappings_resource_type"
      t.check_constraint "(sync_target_type IS NULL) = (sync_target_id IS NULL)",
        name: "external_master_sync_mappings_target_presence"
    end

    create_table :master_sync_receipts, comment: "マスタ同期受領台帳" do |t|
      t.string :public_id, null: false, comment: "公開ID"
      t.string :idempotency_key, null: false, comment: "冪等性キー"
      t.string :request_digest, null: false, comment: "リクエストダイジェスト"
      t.string :source_system, null: false, comment: "同期元システム"
      t.string :resource_type, null: false, comment: "同期リソース種別"
      t.string :external_id, null: false, comment: "同期元外部ID"
      t.integer :response_status, null: false, comment: "確定レスポンスHTTPステータス"
      t.jsonb :response_body, null: false, default: {}, comment: "確定レスポンス本文"
      t.datetime :completed_at, null: false, comment: "処理確定日時"
      t.timestamps

      t.index :public_id, unique: true
      t.index :idempotency_key, unique: true
      t.index %i[source_system resource_type external_id],
        name: "idx_master_sync_receipts_resource"
      t.index :completed_at
      t.check_constraint "response_status BETWEEN 100 AND 599",
        name: "master_sync_receipts_response_status"
    end
  end
end
