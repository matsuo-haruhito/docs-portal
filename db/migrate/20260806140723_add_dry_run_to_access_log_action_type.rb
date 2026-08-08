class AddDryRunToAccessLogActionType < ActiveRecord::Migration[8.1]
  def change
    change_column_comment :access_logs, :action_type, from: nil, to: "操作種別（view/download/bulk_edit/dry_run/external_preview）"
  end
end
