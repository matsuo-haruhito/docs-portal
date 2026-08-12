class AddPreviewBuildReasonToDocumentVersions < ActiveRecord::Migration[8.1]
  def up
    safety_assured do
      add_column :document_versions, :preview_build_reason, :integer,
        default: 0, null: false, comment: "プレビュービルド理由（通常生成/成果物復旧）"
    end
  end

  def down
    safety_assured do
      remove_column :document_versions, :preview_build_reason
    end
  end
end
