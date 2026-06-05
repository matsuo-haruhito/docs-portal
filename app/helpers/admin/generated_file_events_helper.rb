module Admin::GeneratedFileEventsHelper
  ERROR_PREVIEW_LIMIT = 120
  FILTERED_VALUE = "[FILTERED]"

  SENSITIVE_ASSIGNMENT_PATTERN = /\b(authorization|token|secret|api[_-]?key|access[_-]?token|client[_-]?secret)\b\s*[:=]\s*["']?[^"'\s,;]+/i
  BEARER_TOKEN_PATTERN = /\bBearer\s+[A-Za-z0-9._~+\/-]+=*/i
  PRIVATE_PATH_PATTERN = %r{\b[A-Za-z]:[\\/][^\s<>"']+|/(?:Users|home|var|tmp|private|srv|app|workspace)/[^\s<>"']+}

  def generated_file_event_error_preview(error_message)
    text = error_message.to_s.squish
    return "-" if text.blank?

    masked = text
      .gsub(BEARER_TOKEN_PATTERN, "Bearer #{FILTERED_VALUE}")
      .gsub(SENSITIVE_ASSIGNMENT_PATTERN) { "#{Regexp.last_match(1)}=#{FILTERED_VALUE}" }
      .gsub(PRIVATE_PATH_PATTERN, FILTERED_VALUE)

    truncate(masked, length: ERROR_PREVIEW_LIMIT, omission: "...")
  end
end
