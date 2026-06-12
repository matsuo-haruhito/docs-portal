# frozen_string_literal: true

module Admin::WebhookDeliveriesHelper
  def webhook_delivery_endpoint_option_label(endpoint)
    [endpoint.name, endpoint.target_url].compact_blank.join(" / ")
  end

  def webhook_delivery_endpoint_selected_option(endpoint)
    return nil if endpoint.blank?

    { value: endpoint.id, text: webhook_delivery_endpoint_option_label(endpoint) }
  end
end
