class AddRetryCountToWebhookDeliveries < ActiveRecord::Migration[8.1]
  def change
    add_column :webhook_deliveries, :retry_count, :integer, default: 0, null: false, comment: "自動リトライ回数"
  end
end
