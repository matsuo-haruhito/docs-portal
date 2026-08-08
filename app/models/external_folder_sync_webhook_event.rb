class ExternalFolderSyncWebhookEvent < ApplicationRecord
  include PublicIdentifiable

  public_id_prefix "efevt"

  SOURCE_UNAVAILABLE_ERROR_MESSAGE = "同期元が存在しないか無効です。"
  RUNNING_COALESCED_ERROR_MESSAGE = "同期実行中のため、次回の整合処理まで保留しました。"
  RECENT_ENQUEUED_COALESCED_ERROR_MESSAGE = "同じ同期元の同期ジョブが登録済みのため、次回の整合処理まで保留しました。"
  COALESCED_INTO_EVENT_ERROR_MESSAGE = "同じ同期元のWebhook通知として1回の同期へ集約しました。"
  ENQUEUE_FAILED_ERROR_MESSAGE = "外部フォルダ同期ジョブを登録できなかったため、再処理待ちへ戻しました。"
  COALESCED_ERROR_MESSAGES = [
    RUNNING_COALESCED_ERROR_MESSAGE,
    RECENT_ENQUEUED_COALESCED_ERROR_MESSAGE
  ].freeze
  DELIVERY_STALE_AFTER = 15.minutes
  STALE_DELIVERY_RECOVERED_ERROR_MESSAGE = "Webhook同期ジョブが期限内に完了しなかったため、再処理待ちへ戻しました。"

  belongs_to :external_folder_sync_source, optional: true
  belongs_to :external_folder_sync_subscription, optional: true
  belongs_to :external_folder_sync_run, optional: true

  enum :provider, {
    google_drive: 0,
    sharepoint: 1
  }

  enum :status, {
    received: 0,
    enqueued: 1,
    ignored: 2,
    failed: 3,
    completed: 4,
    processing: 5
  }

  scope :stale_enqueued, ->(at = Time.current) {
    enqueued.where("updated_at <= ?", at - DELIVERY_STALE_AFTER)
  }
  scope :stale_processing, ->(at = Time.current) {
    processing.where("updated_at <= ?", at - DELIVERY_STALE_AFTER)
  }

  validates :provider, :status, :received_at, presence: true

  def to_param
    public_id
  end

  def coalesced_ignored?
    ignored? && COALESCED_ERROR_MESSAGES.include?(error_message.to_s)
  end

  def ignored_reason
    return nil unless ignored?

    case error_message.to_s
    when RUNNING_COALESCED_ERROR_MESSAGE then "coalesced_running"
    when RECENT_ENQUEUED_COALESCED_ERROR_MESSAGE then "coalesced_recent"
    when SOURCE_UNAVAILABLE_ERROR_MESSAGE then "source_unavailable"
    else "other"
    end
  end
end
