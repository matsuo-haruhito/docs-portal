class ExternalFolderSyncSubscriptionRenewalJob < ApplicationJob
  queue_as :default

  DEFAULT_BATCH_SIZE = 100

  def perform(limit: DEFAULT_BATCH_SIZE)
    active_source_ids = ExternalFolderSyncSubscription
      .google_drive
      .active
      .where("expires_at <= ?", ExternalFolderSync::GoogleDriveSubscriptionManager::RENEW_WINDOW.from_now)
      .order(:expires_at, :id)
      .limit(limit)
      .pluck(:external_folder_sync_source_id)
      .uniq

    ExternalFolderSyncSource
      .enabled_only
      .google_drive
      .where(id: active_source_ids)
      .find_each do |source|
        renew_source!(source)
      end

    mark_expired_subscriptions!
  end

  private

  def renew_source!(source)
    ExternalFolderSync::GoogleDriveSubscriptionManager.new(
      source:,
      callback_url: callback_url
    ).renew_expiring!
  rescue ExternalFolderSync::GoogleDriveSubscriptionManager::Error => e
    source.external_folder_sync_subscriptions.google_drive.active.update_all(
      status: ExternalFolderSyncSubscription.statuses.fetch(:failed),
      last_error_message: e.message,
      updated_at: Time.current
    )
  end

  def mark_expired_subscriptions!
    ExternalFolderSyncSubscription
      .google_drive
      .active
      .where("expires_at < ?", Time.current)
      .update_all(
        status: ExternalFolderSyncSubscription.statuses.fetch(:expired),
        last_error_message: "Google Drive webhook subscription expired before renewal",
        updated_at: Time.current
      )
  end

  def callback_url
    Rails.application.routes.url_helpers.external_folder_sync_webhooks_google_drive_url(
      host: Rails.application.config.action_mailer.default_url_options.fetch(:host)
    )
  end
end
