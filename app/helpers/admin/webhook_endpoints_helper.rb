# frozen_string_literal: true

module Admin::WebhookEndpointsHelper
  WEBHOOK_ENDPOINT_TARGET_URL_DISPLAY_LIMIT = 120

  def webhook_endpoint_table_columns
    [
      table_preferences_column(:name, label: "名称", default_width: 180, pinned: true, sortable: true),
      table_preferences_column(:target_url, label: "送信先URL", default_width: 320, overflow: :ellipsis),
      table_preferences_column(:event_types, label: "イベント", default_width: 260),
      table_preferences_column(:active, label: "状態", default_width: 100, pinned: true),
      table_preferences_column(:actions, label: "操作", default_width: 150, pinned: true)
    ]
  end

  def webhook_delivery_table_columns
    [
      table_preferences_column(:created_at, label: "作成日時", default_width: 180, pinned: true, sortable: true),
      table_preferences_column(:endpoint, label: "設定", default_width: 180, pinned: true, sortable: true),
      table_preferences_column(:event_type, label: "イベント", default_width: 220),
      table_preferences_column(:status, label: "ステータス", default_width: 110, pinned: true),
      table_preferences_column(:response_status, label: "HTTP", default_width: 90),
      table_preferences_column(:error_message, label: "エラー", default_width: 340, overflow: :ellipsis),
      table_preferences_column(:actions, label: "操作", default_width: 170, pinned: true)
    ]
  end

  def webhook_endpoint_display_target_url(target_url)
    raw_url = target_url.to_s.strip
    return "-" if raw_url.blank?

    uri = URI.parse(raw_url)
    return masked_webhook_endpoint_target_url(raw_url) if uri.scheme.blank? || uri.host.blank?

    display_url = "#{uri.scheme}://#{webhook_endpoint_url_authority(uri)}#{uri.path.presence || '/'}"
    uri.query.present? ? "#{display_url}?..." : display_url
  rescue URI::InvalidURIError
    masked_webhook_endpoint_target_url(raw_url)
  end

  def webhook_endpoint_status_label(endpoint)
    endpoint.active? ? "有効" : "停止"
  end

  def webhook_endpoint_delete_confirm_message(endpoint)
    event_labels = endpoint.normalized_event_types.map { |event_type| webhook_event_type_label(event_type) }.join(", ").presence || "-"

    [
      "Webhook設定を削除します。",
      "名称: #{endpoint.name}",
      "送信先URL: #{webhook_endpoint_display_target_url(endpoint.target_url)}",
      "イベント: #{event_labels}",
      "状態: #{webhook_endpoint_status_label(endpoint)}",
      "停止ではなく設定削除の操作です。",
      "この設定に紐づく送信履歴も削除対象になります。",
      "以後この通知先へWebhookは送信されません。削除しますか？"
    ].join("\n")
  end

  def webhook_delivery_status_label(delivery)
    case delivery.status.to_s
    when "succeeded"
      "成功"
    when "failed"
      "失敗"
    when "pending"
      "送信待ち"
    else
      delivery.status.to_s
    end
  end

  def webhook_delivery_status_filter_options
    [
      ["all", "すべて"],
      ["failed", "失敗のみ"],
      ["pending", "送信待ち"],
      ["succeeded", "成功"]
    ]
  end

  def webhook_delivery_status_filter_label(value)
    webhook_delivery_status_filter_options.to_h.fetch(value.to_s, "すべて")
  end

  def webhook_delivery_status_count(counts, status)
    status_key = status.to_s
    counts[status_key] || counts[WebhookDelivery.statuses.fetch(status_key)] || 0
  end

  def webhook_delivery_response_status_label(delivery)
    delivery.response_status.present? ? delivery.response_status.to_s : "未取得"
  end

  def webhook_delivery_response_status_context(delivery)
    delivery.response_status.present? ? "HTTP #{delivery.response_status}" : "HTTP未取得"
  end

  def webhook_delivery_detail_link_cue(delivery)
    [
      delivery.webhook_endpoint.name,
      webhook_event_type_label(delivery),
      webhook_delivery_status_label(delivery)
    ].compact_blank.join(" / ").then do |context|
      "#{context} の詳細を、検索条件とページを保って開く"
    end
  end

  def webhook_event_type_label(event_or_value)
    value = event_or_value.respond_to?(:event_type) ? event_or_value.event_type : event_or_value
    localized_label("webhook_events.event_type", value)
  end

  private

  def webhook_endpoint_url_authority(uri)
    host = uri.host.to_s
    host = "[#{host}]" if host.include?(":") && !host.start_with?("[")

    default_port = { "http" => 80, "https" => 443 }.fetch(uri.scheme, nil)
    uri.port.present? && uri.port != default_port ? "#{host}:#{uri.port}" : host
  end

  def masked_webhook_endpoint_target_url(raw_url)
    base_url = raw_url.split(/[?#]/, 2).first.presence || "-"
    display_base = base_url.length > WEBHOOK_ENDPOINT_TARGET_URL_DISPLAY_LIMIT ? "#{base_url.first(WEBHOOK_ENDPOINT_TARGET_URL_DISPLAY_LIMIT - 3)}..." : base_url
    raw_url.include?("?") ? "#{display_base}?..." : display_base
  end
end
