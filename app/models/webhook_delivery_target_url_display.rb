# frozen_string_literal: true

require "uri"

class WebhookDeliveryTargetUrlDisplay
  QUERY_MARKER = "?..."

  def initialize(target_url)
    @target_url = target_url.to_s
  end

  def to_s
    return "-" if @target_url.blank?

    parsed_url || fallback_url
  end

  private

  def parsed_url
    uri = URI.parse(@target_url)
    return nil unless uri.scheme.present? && uri.host.present?

    display = +"#{uri.scheme}://#{uri.host}"
    display << ":#{uri.port}" if uri.port && !default_port?(uri)
    display << uri.path if uri.path.present?
    display << QUERY_MARKER if uri.query.present?
    display
  rescue URI::InvalidURIError
    nil
  end

  def fallback_url
    base, separator = @target_url.split(/[?#]/, 2)
    display = base.presence || "-"
    separator.nil? ? display : "#{display}#{QUERY_MARKER}"
  end

  def default_port?(uri)
    (uri.scheme == "https" && uri.port == 443) || (uri.scheme == "http" && uri.port == 80)
  end
end
