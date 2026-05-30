# frozen_string_literal: true

module Admin::WebhookEndpointsHelper
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

  def webhook_endpoint_status_label(endpoint)
    endpoint.active? ? "有効" : "停止"
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

  def webhook_event_type_label(event_or_value)
    value = event_or_value.respond_to?(:event_type) ? event_or_value.event_type : event_or_value
    localized_label("webhook_events.event_type", value)
  end
end
