class AddDocusaurusPreviewBuildRecoveryState < ActiveRecord::Migration[8.1]
  def up
    safety_assured do
      lock_target_table!

      add_column :document_versions, :preview_build_attempt_count, :integer,
        default: 0, null: false, comment: "プレビュービルド試行回数"
      add_column :document_versions, :preview_build_enqueued_at, :datetime,
        comment: "プレビュービルドキュー登録日時"
      add_column :document_versions, :preview_build_started_at, :datetime,
        comment: "プレビュービルド開始日時"
      add_column :document_versions, :preview_build_retry_at, :datetime,
        comment: "プレビュービルド次回再試行日時"
      add_column :document_versions, :preview_build_claim_token, :string,
        comment: "プレビュービルド実行権トークン"
      add_column :document_versions, :preview_build_reconciled_at, :datetime,
        comment: "プレビュービルド整合性確認日時"

      add_index :document_versions,
        %i[preview_build_status preview_build_enqueued_at],
        name: "idx_document_versions_preview_enqueued"
      add_index :document_versions,
        %i[preview_build_status preview_build_started_at],
        name: "idx_document_versions_preview_started"
      add_index :document_versions,
        %i[preview_build_status preview_build_retry_at],
        name: "idx_document_versions_preview_retry"
      add_index :document_versions,
        :preview_build_reconciled_at,
        name: "idx_document_versions_preview_reconciled"

      add_check_constraint :document_versions,
        "preview_build_attempt_count >= 0",
        name: "document_versions_preview_attempt_count_non_negative",
        validate: false
      validate_check_constraint :document_versions,
        name: "document_versions_preview_attempt_count_non_negative"
    end
  end

  def down
    safety_assured do
      lock_target_table!

      remove_check_constraint :document_versions,
        name: "document_versions_preview_attempt_count_non_negative"
      remove_index :document_versions,
        name: "idx_document_versions_preview_reconciled"
      remove_index :document_versions,
        name: "idx_document_versions_preview_retry"
      remove_index :document_versions,
        name: "idx_document_versions_preview_started"
      remove_index :document_versions,
        name: "idx_document_versions_preview_enqueued"

      remove_column :document_versions, :preview_build_reconciled_at
      remove_column :document_versions, :preview_build_claim_token
      remove_column :document_versions, :preview_build_retry_at
      remove_column :document_versions, :preview_build_started_at
      remove_column :document_versions, :preview_build_enqueued_at
      remove_column :document_versions, :preview_build_attempt_count
    end
  end

  private

  def lock_target_table!
    execute "LOCK TABLE document_versions IN ACCESS EXCLUSIVE MODE"
  end
end
