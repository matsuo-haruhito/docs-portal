module ExternalFolderSync
  class GoogleDriveSubscriptionManager
    class Error < StandardError; end

    DEFAULT_TTL = 6.days
    RENEW_WINDOW = 12.hours

    def initialize(source:, callback_url:)
      @source = source
      @callback_url = callback_url
    end

    def subscribe!
      ensure_supported!
      stop_active_subscription!

      expires_at = DEFAULT_TTL.from_now
      channel_id = SecureRandom.uuid
      token = SecureRandom.hex(32)
      response = client.watch_changes(
        callback_url:,
        channel_id:,
        token:,
        expires_at:,
        page_token: source.cursor.presence
      )

      source.external_folder_sync_subscriptions.create!(
        provider: :google_drive,
        status: :active,
        provider_subscription_id: response["id"].presence || channel_id,
        provider_channel_id: response["id"].presence || channel_id,
        provider_resource_id: response.fetch("resourceId"),
        callback_url:,
        verification_token_digest: digest(token),
        expires_at: parse_expiration(response["expiration"]) || expires_at,
        last_renewed_at: Time.current,
        last_error_message: nil,
        provider_metadata: {
          resource_uri: response["resourceUri"],
          kind: response["kind"],
          watch_response: response.except("token")
        }
      )
    rescue ExternalFolderSync::GoogleDriveClient::Error, KeyError => e
      source.external_folder_sync_subscriptions.create!(
        provider: :google_drive,
        status: :failed,
        callback_url:,
        last_error_message: e.message
      )
      raise Error, e.message
    end

    def stop_active_subscription!
      source.external_folder_sync_subscriptions.google_drive.active.find_each do |subscription|
        stop_subscription!(subscription)
      end
    end

    def renew_expiring!
      return unless source.external_folder_sync_subscriptions.google_drive.active.where("expires_at <= ?", RENEW_WINDOW.from_now).exists?

      subscribe!
    end

    private

    attr_reader :source, :callback_url

    def client
      @client ||= ExternalFolderSync::GoogleDriveClient.new(source:)
    end

    def ensure_supported!
      raise Error, "Only Google Drive sync is supported" unless source.google_drive?
      raise Error, "Sync source is disabled" unless source.enabled?
      raise Error, "Callback URL is required" if callback_url.blank?
    end

    def stop_subscription!(subscription)
      if subscription.provider_channel_id.present? && subscription.provider_resource_id.present?
        client.stop_channel(
          channel_id: subscription.provider_channel_id,
          resource_id: subscription.provider_resource_id
        )
      end

      subscription.update!(status: :disabled, last_error_message: nil)
    rescue ExternalFolderSync::GoogleDriveClient::Error => e
      subscription.update!(status: :failed, last_error_message: e.message)
    end

    def digest(value)
      Digest::SHA256.hexdigest(value.to_s)
    end

    def parse_expiration(value)
      return if value.blank?

      Time.zone.at(value.to_i / 1000.0)
    end
  end
end
