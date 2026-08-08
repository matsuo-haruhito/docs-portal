class AddWebhookDeliveryRetryClaims < ActiveRecord::Migration[8.1]
  def up
    safety_assured do
      execute "LOCK TABLE webhook_deliveries IN ACCESS EXCLUSIVE MODE"

    add_column :webhook_deliveries, :retry_claim_token, :string,
      comment: "自動再送実行権トークン"
    add_column :webhook_deliveries, :retry_claimed_at, :datetime,
      comment: "自動再送実行権取得日時"
    change_column_comment :webhook_deliveries, :status,
      from: "ステータス",
      to: "ステータス（送信待ち/成功/失敗/自動再送中）"

    safety_assured do
      add_index :webhook_deliveries,
        %i[status retry_claimed_at],
        name: "idx_webhook_deliveries_retry_claimed"
      add_index :webhook_deliveries,
        :retry_claim_token,
        unique: true,
        where: "retry_claim_token IS NOT NULL",
        name: "idx_webhook_deliveries_unique_retry_claim"
    end

    add_check_constraint :webhook_deliveries,
      "retry_count >= 0",
      name: "webhook_deliveries_retry_count_non_negative",
      validate: false
    validate_check_constraint :webhook_deliveries,
      name: "webhook_deliveries_retry_count_non_negative"
    add_check_constraint :webhook_deliveries,
      "(status = 3) = (retry_claim_token IS NOT NULL AND retry_claimed_at IS NOT NULL)",
      name: "webhook_deliveries_retry_claim_presence",
      validate: false
    validate_check_constraint :webhook_deliveries,
      name: "webhook_deliveries_retry_claim_presence"
    end
  end

  def down
    remove_check_constraint :webhook_deliveries,
      name: "webhook_deliveries_retry_claim_presence"
    remove_check_constraint :webhook_deliveries,
      name: "webhook_deliveries_retry_count_non_negative"
    remove_index :webhook_deliveries,
      name: "idx_webhook_deliveries_unique_retry_claim"
    remove_index :webhook_deliveries,
      name: "idx_webhook_deliveries_retry_claimed"
    change_column_comment :webhook_deliveries, :status,
      from: "ステータス（送信待ち/成功/失敗/自動再送中）",
      to: "ステータス"
    remove_column :webhook_deliveries, :retry_claimed_at
    remove_column :webhook_deliveries, :retry_claim_token
  end
end
