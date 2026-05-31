class ExternalFolderSyncWebhookEvent < ApplicationRecord
  include PublicIdentifiable

  public_id_prefix "efevt"

  SOURCE_UNAVAILABLE_ERROR_MESSAGE = "External folder sync source is missing or disabled"
  RUNNING_COALESCED_ERROR_MESSAGE = "External folder sync is already running; webhook event was coalesced"
  RECENT_ENQUEUED_COALESCED_ERROR_MESSAGE = "A recent webhook sync job is already enqueued; webhook event was coalesced"
  COALESCED_ERROR_MESSAGES = [
    RUNNING_COALESCED_ERROR_MESSAGE,
    RECENT_ENQUEUED_COALESCED_ERROR_MESSAGE
  ].freeze

  belongs_to :external_folder_sync_source, optional: true
  belongs_to :external_folder_sync_subscription, optional: true

  enum :provider, {
    google_drive: 0,
    sharepoint: 1
  }

  enum :status, {
    received: 0,
    enqueued: 1,
    ignored: 2,
    failed: 3,
    completed: 4
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
