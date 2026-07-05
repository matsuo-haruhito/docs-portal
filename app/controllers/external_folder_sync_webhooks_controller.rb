class ExternalFolderSyncWebhooksController < ActionController::Base
  skip_forgery_protection

  FILTERED_SECRET_VALUE = "[FILTERED]".freeze
  SECRET_HEADER_KEYS = %w[X_GOOG_CHANNEL_TOKEN CLIENT_STATE].freeze
  READ_ONLY_MAINTENANCE_ENV = "READ_ONLY_MAINTENANCE".freeze

  def google_drive
    event = record_event!(provider: :google_drive)
    enqueue_event_if_needed(event)

    head :ok
  end

  def sharepoint
    validation_token = params[:validationToken].to_s
    if validation_token.present?
      render plain: validation_token, content_type: "text/plain"
      return
    end

    events = sharepoint_notifications.map do |notification|
      record_event!(provider: :sharepoint, payload: notification)
    end
    events.each { enqueue_event_if_needed(_1) }

    head :accepted
  end

  private

  def enqueue_event_if_needed(event)
    return unless event.external_folder_sync_source.present?
    return unless event.received?
    return if read_only_maintenance_mode?

    ExternalFolderSyncWebhookEventJob.perform_later(event.id)
  end

  def read_only_maintenance_mode?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch(READ_ONLY_MAINTENANCE_ENV, nil))
  end

  def record_event!(provider:, payload: request_payload)
    subscription = find_subscription(provider:, payload:)
    source = subscription&.external_folder_sync_source
    event_key = event_key_for(provider:, payload:, subscription:)
    verified = verified_subscription?(provider:, payload:, subscription:)

    ExternalFolderSyncWebhookEvent.find_or_create_by!(provider:, event_key:) do |event|
      event.external_folder_sync_subscription = subscription
      event.external_folder_sync_source = source
      event.status = source.present? && verified ? :received : :ignored
      event.received_at = Time.current
      event.headers_json = filtered_headers
      event.payload_json = filtered_payload(provider:, payload:)
      event.error_message = event_error_message(source:, verified:)
    end
  end

  def find_subscription(provider:, payload:)
    case provider.to_s
    when "google_drive"
      channel_id = request.headers["X-Goog-Channel-ID"].presence
      resource_id = request.headers["X-Goog-Resource-ID"].presence
      ExternalFolderSyncSubscription.active.find_by(provider:, provider_channel_id: channel_id) ||
        ExternalFolderSyncSubscription.active.find_by(provider:, provider_resource_id: resource_id)
    when "sharepoint"
      subscription_id = payload["subscriptionId"].presence
      ExternalFolderSyncSubscription.active.find_by(provider:, provider_subscription_id: subscription_id)
    end
  end

  def verified_subscription?(provider:, payload:, subscription:)
    return false if subscription.blank?

    case provider.to_s
    when "google_drive"
      secure_digest_match?(request.headers["X-Goog-Channel-Token"], subscription.verification_token_digest)
    when "sharepoint"
      expected_digest = subscription.verification_token_digest.to_s
      return true if expected_digest.blank?

      secure_digest_match?(payload["clientState"], expected_digest)
    else
      true
    end
  end

  def secure_digest_match?(token, expected_digest)
    token = token.to_s
    expected_digest = expected_digest.to_s
    token.present? && expected_digest.present? && ActiveSupport::SecurityUtils.secure_compare(Digest::SHA256.hexdigest(token), expected_digest)
  end

  def event_error_message(source:, verified:)
    return "Matching external folder sync source was not found" if source.blank?
    return "Webhook verification token did not match" unless verified
  end

  def event_key_for(provider:, payload:, subscription:)
    case provider.to_s
    when "google_drive"
      [
        request.headers["X-Goog-Channel-ID"],
        request.headers["X-Goog-Resource-ID"],
        request.headers["X-Goog-Resource-State"],
        request.headers["X-Goog-Message-Number"]
      ].compact_blank.join(":").presence || fallback_event_key(provider)
    when "sharepoint"
      [
        payload["subscriptionId"],
        payload["resource"],
        payload["changeType"],
        client_state_fingerprint(payload["clientState"]),
        payload["sequenceNumber"]
      ].compact_blank.join(":").presence || fallback_event_key(provider)
    else
      [provider, subscription&.id, SecureRandom.uuid].compact.join(":")
    end
  end

  def client_state_fingerprint(client_state)
    client_state = client_state.to_s
    return if client_state.blank?

    "client_state:#{Digest::SHA256.hexdigest(client_state)}"
  end

  def fallback_event_key(provider)
    [provider, Time.current.to_f, SecureRandom.uuid].join(":")
  end

  def request_payload
    raw_body = request.raw_post.to_s
    return {} if raw_body.blank?

    JSON.parse(raw_body)
  rescue JSON::ParserError
    { "raw" => raw_body }
  end

  def sharepoint_notifications
    payload = request_payload
    notifications = payload.key?("value") ? payload["value"] : payload.presence

    Array.wrap(notifications)
  end

  def filtered_payload(provider:, payload:)
    payload = payload.presence || {}
    return payload unless provider.to_s == "sharepoint" && payload.key?("clientState")

    payload.merge("clientState" => FILTERED_SECRET_VALUE)
  end

  def filtered_headers
    request.headers.env.each_with_object({}) do |(key, value), result|
      next unless key.start_with?("HTTP_X_GOOG_") || key.in?(%w[HTTP_CLIENT_STATE HTTP_USER_AGENT CONTENT_TYPE])

      header_key = key.sub(/\AHTTP_/, "")
      next if SECRET_HEADER_KEYS.include?(header_key)

      result[header_key] = value.to_s
    end
  end
end
