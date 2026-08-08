class AddGeneratedFileEventDispatchClaims < ActiveRecord::Migration[8.1]
  def change
    add_column :generated_file_events, :dispatch_group_id, :string,
      comment: "生成イベントdispatchグループID"
    add_column :generated_file_events, :dispatch_claim_token, :string,
      comment: "生成イベントdispatch実行権トークン"
    add_column :generated_file_events, :dispatch_claimed_at, :datetime,
      comment: "生成イベントdispatch実行権取得日時"
    add_column :generated_file_events, :dispatch_heartbeat_at, :datetime,
      comment: "生成イベントdispatch最終ハートビート日時"

    safety_assured do
      add_index :generated_file_events,
        %i[status dispatch_heartbeat_at],
        name: "idx_generated_file_events_dispatch_stale"
      add_index :generated_file_events,
        %i[dispatch_group_id dispatch_claim_token status],
        name: "idx_generated_file_events_dispatch_owner"
    end
  end
end
