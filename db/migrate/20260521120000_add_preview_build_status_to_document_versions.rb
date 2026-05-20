class AddPreviewBuildStatusToDocumentVersions < ActiveRecord::Migration[8.0]
  def change
    add_column :document_versions, :preview_build_status, :integer, null: false, default: 0, comment: "プレビュービルドステータス"
    add_column :document_versions, :preview_build_error_message, :text, comment: "プレビュービルドエラーメッセージ"
    add_column :document_versions, :preview_build_attempted_at, :datetime, comment: "プレビュービルド試行日時"
    add_column :document_versions, :preview_build_completed_at, :datetime, comment: "プレビュービルド完了日時"

    add_index :document_versions, :preview_build_status
    add_index :document_versions, :preview_build_attempted_at
  end
end
