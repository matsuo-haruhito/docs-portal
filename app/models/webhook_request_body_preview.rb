# frozen_string_literal: true

class WebhookRequestBodyPreview
  MAX_LENGTH = 600
  MASK = "[masked]"
  SENSITIVE_KEY_PATTERN = /secret|token|authorization|password|email|name|phone|address/i
  SENSITIVE_TEXT_PATTERN = /((?:secret|token|authorization|password|email|name|phone|address)\s*[=:]\s*)[^\s&]+/i

  def initialize(request_body)
    @request_body = request_body.to_s
  end

  def to_s
    return "-" if @request_body.blank?

    truncate(render_preview)
  end

  private

  def render_preview
    parsed = JSON.parse(@request_body)
    JSON.pretty_generate(mask_sensitive_values(parsed))
  rescue JSON::ParserError
    mask_sensitive_text(@request_body)
  end

  def mask_sensitive_values(value, key = nil)
    return MASK if sensitive_key?(key)

    case value
    when Hash
      value.each_with_object({}) do |(child_key, child_value), sanitized|
        sanitized[child_key] = mask_sensitive_values(child_value, child_key)
      end
    when Array
      value.map { |item| mask_sensitive_values(item) }
    else
      value
    end
  end

  def sensitive_key?(key)
    key.to_s.match?(SENSITIVE_KEY_PATTERN)
  end

  def mask_sensitive_text(text)
    text.gsub(SENSITIVE_TEXT_PATTERN) { "#{$1}#{MASK}" }
  end

  def truncate(text)
    return text if text.length <= MAX_LENGTH

    "#{text[0, MAX_LENGTH]}\n...省略..."
  end
end
