class AddExternalFolderSyncRunLeases < ActiveRecord::Migration[8.1]
  def up
    safety_assured do
      execute <<~SQL.squish
      LOCK TABLE external_folder_sync_runs,
                 external_folder_sync_sources,
                 external_folder_sync_webhook_events
      IN ACCESS EXCLUSIVE MODE
    SQL

    add_column :external_folder_sync_runs, :enqueued_at, :datetime,
      comment: "同期ジョブ登録日時"
    add_column :external_folder_sync_runs, :heartbeat_at, :datetime,
      comment: "同期実行最終ハートビート日時"
    add_column :external_folder_sync_sources, :active_sync_run_id, :bigint,
      comment: "実行権を保持する外部フォルダ同期実行ID"
    add_column :external_folder_sync_sources, :sync_lease_expires_at, :datetime,
      comment: "同期実行権有効期限"
    add_column :external_folder_sync_webhook_events, :external_folder_sync_run_id, :bigint,
      comment: "予約・実行に紐づく外部フォルダ同期実行ID"

    add_foreign_key :external_folder_sync_sources, :external_folder_sync_runs,
      column: :active_sync_run_id,
      validate: false
    validate_foreign_key :external_folder_sync_sources, :external_folder_sync_runs,
      column: :active_sync_run_id
    add_foreign_key :external_folder_sync_webhook_events, :external_folder_sync_runs,
      validate: false
    validate_foreign_key :external_folder_sync_webhook_events, :external_folder_sync_runs

    backfill_existing_active_runs!

    safety_assured do
      add_index :external_folder_sync_sources,
        :active_sync_run_id,
        unique: true,
        where: "active_sync_run_id IS NOT NULL",
        name: "idx_ext_sync_sources_unique_active_run"
      add_index :external_folder_sync_sources,
        :sync_lease_expires_at,
        where: "active_sync_run_id IS NOT NULL",
        name: "idx_ext_sync_sources_on_lease_expiry"
      add_index :external_folder_sync_runs,
        :external_folder_sync_source_id,
        unique: true,
        where: "status IN (0, 1)",
        name: "idx_ext_sync_runs_one_active_per_source"
      add_index :external_folder_sync_runs,
        %i[status enqueued_at],
        name: "idx_ext_sync_runs_on_status_enqueued_at"
      add_index :external_folder_sync_runs,
        %i[status heartbeat_at],
        name: "idx_ext_sync_runs_on_status_heartbeat_at"
      add_index :external_folder_sync_webhook_events,
        %i[external_folder_sync_run_id status],
        name: "idx_ext_sync_events_on_run_status"
      add_index :external_folder_sync_webhook_events,
        %i[external_folder_sync_source_id status received_at],
        name: "idx_ext_sync_events_on_source_status_received"
    end

    add_check_constraint :external_folder_sync_sources,
      "(active_sync_run_id IS NULL) = (sync_lease_expires_at IS NULL)",
      name: "external_folder_sync_sources_lease_presence",
      validate: false
    validate_check_constraint :external_folder_sync_sources,
      name: "external_folder_sync_sources_lease_presence"
    end
  end

  def down
    remove_check_constraint :external_folder_sync_sources,
      name: "external_folder_sync_sources_lease_presence"
    remove_index :external_folder_sync_webhook_events,
      name: "idx_ext_sync_events_on_source_status_received"
    remove_index :external_folder_sync_webhook_events,
      name: "idx_ext_sync_events_on_run_status"
    remove_index :external_folder_sync_runs,
      name: "idx_ext_sync_runs_on_status_heartbeat_at"
    remove_index :external_folder_sync_runs,
      name: "idx_ext_sync_runs_on_status_enqueued_at"
    remove_index :external_folder_sync_runs,
      name: "idx_ext_sync_runs_one_active_per_source"
    remove_index :external_folder_sync_sources,
      name: "idx_ext_sync_sources_on_lease_expiry"
    remove_index :external_folder_sync_sources,
      name: "idx_ext_sync_sources_unique_active_run"

    remove_foreign_key :external_folder_sync_webhook_events, :external_folder_sync_runs
    remove_foreign_key :external_folder_sync_sources,
      column: :active_sync_run_id
    remove_column :external_folder_sync_webhook_events, :external_folder_sync_run_id
    remove_column :external_folder_sync_sources, :sync_lease_expires_at
    remove_column :external_folder_sync_sources, :active_sync_run_id
    remove_column :external_folder_sync_runs, :heartbeat_at
    remove_column :external_folder_sync_runs, :enqueued_at
  end

  private

  def backfill_existing_active_runs!
    duplicates = connection.select_values(<<~SQL.squish)
      SELECT external_folder_sync_source_id
      FROM external_folder_sync_runs
      WHERE status IN (0, 1)
      GROUP BY external_folder_sync_source_id
      HAVING COUNT(*) > 1
    SQL
    raise "外部フォルダ同期元に複数のactive runがあります: #{duplicates.join(', ')}" if duplicates.any?

    safety_assured do
      execute <<~SQL.squish
        UPDATE external_folder_sync_runs
        SET enqueued_at = COALESCE(enqueued_at, created_at),
            heartbeat_at = CASE
              WHEN status = 1 THEN COALESCE(heartbeat_at, updated_at, started_at, created_at)
              ELSE heartbeat_at
            END
        WHERE status IN (0, 1)
      SQL
      execute <<~SQL.squish
        UPDATE external_folder_sync_sources AS sources
        SET active_sync_run_id = runs.id,
            sync_lease_expires_at = CASE
              WHEN runs.status = 0 THEN COALESCE(runs.enqueued_at, runs.created_at) + INTERVAL '15 minutes'
              ELSE COALESCE(runs.heartbeat_at, runs.updated_at, runs.started_at, runs.created_at) + INTERVAL '1 hour'
            END
        FROM external_folder_sync_runs AS runs
        WHERE runs.external_folder_sync_source_id = sources.id
          AND runs.status IN (0, 1)
      SQL
    end
  end
end
