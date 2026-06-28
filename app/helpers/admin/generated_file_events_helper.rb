module Admin::GeneratedFileEventsHelper
  ERROR_PREVIEW_LIMIT = 120
  DIAGNOSTIC_PREVIEW_LIMIT = 4_000
  FILTERED_VALUE = "[FILTERED]"

  SENSITIVE_KEY_PATTERN = /\b(authorization|token|secret|api[_-]?key|access[_-]?token|client[_-]?secret)\b/i
  SENSITIVE_ASSIGNMENT_PATTERN = /\b(token|secret|api[_-]?key|access[_-]?token|client[_-]?secret)\b\s*[:=]\s*["']?[^"'\s,;]+/i
  AUTHORIZATION_HEADER_PATTERN = /\b(Authorization)\s*:\s*(Bearer|Basic)\s+[^\s,;]+/i
  BEARER_TOKEN_PATTERN = /\bBearer\s+[A-Za-z0-9._~+\/-]+=*/i
  PRIVATE_PATH_PATTERN = %r{\b[A-Za-z]:[\\/][^\s<>"']+|/(?:Users|home|var|tmp|private|srv|app|workspace)/[^\s<>"']+}

  def generated_file_event_error_preview(error_message)
    text = mask_generated_file_event_diagnostic_value(error_message.to_s.squish)
    return "-" if text.blank?

    truncate(text, length: ERROR_PREVIEW_LIMIT, omission: "...")
  end

  def generated_file_event_diagnostic_preview(value)
    text = mask_generated_file_event_diagnostic_value(value.to_s)
    return "-" if text.blank?

    truncate(text, length: DIAGNOSTIC_PREVIEW_LIMIT, omission: "...")
  end

  def generated_file_event_metadata_preview(metadata)
    JSON.pretty_generate(mask_generated_file_event_metadata(metadata || {}))
  end

  private

  def mask_generated_file_event_metadata(value, key: nil)
    if key.to_s.match?(SENSITIVE_KEY_PATTERN)
      FILTERED_VALUE
    elsif value.is_a?(Hash)
      value.each_with_object({}) do |(child_key, child_value), result|
        result[child_key] = mask_generated_file_event_metadata(child_value, key: child_key)
      end
    elsif value.is_a?(Array)
      value.map { |child_value| mask_generated_file_event_metadata(child_value, key:) }
    elsif value.is_a?(String)
      mask_generated_file_event_diagnostic_value(value)
    else
      value
    end
  end

  def mask_generated_file_event_diagnostic_value(value)
    value.to_s
      .gsub(AUTHORIZATION_HEADER_PATTERN) { "#{Regexp.last_match(1)}: #{Regexp.last_match(2)} #{FILTERED_VALUE}" }
      .gsub(BEARER_TOKEN_PATTERN, "Bearer #{FILTERED_VALUE}")
      .gsub(SENSITIVE_ASSIGNMENT_PATTERN) { "#{Regexp.last_match(1)}=#{FILTERED_VALUE}" }
      .gsub(PRIVATE_PATH_PATTERN, FILTERED_VALUE)
  end
end
