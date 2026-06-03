# frozen_string_literal: true

class WebhookDeliveryDiagnosticPreview
  MAX_LENGTH = 600
  MASK = "[masked]"
  AUTHORIZATION_PATTERN = /((?:authorization)\s*[=:]\s*)[^\n\r]+/i
  SENSITIVE_TEXT_PATTERN = /((?:secret|token|password|email|name|phone|address|client_secret|access_token)\s*[=:]\s*)[^\s&]+/i

  def initialize(value)
    @value = value.to_s
  end

  def to_s
    return "-" if @value.empty?

    truncate(mask_sensitive_text(@value))
  end

  private

  def mask_sensitive_text(text)
    text
      .gsub(AUTHORIZATION_PATTERN) { "#{Regexp.last_match(1)}#{MASK}" }
      .gsub(SENSITIVE_TEXT_PATTERN) { "#{Regexp.last_match(1)}#{MASK}" }
  end

  def truncate(text)
    return text if text.length <= MAX_LENGTH

    "#{text[0, MAX_LENGTH]}\n...省略..."
  end
end
