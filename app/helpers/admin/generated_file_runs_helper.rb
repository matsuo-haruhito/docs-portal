module Admin::GeneratedFileRunsHelper
  GENERATED_FILE_RUN_DIAGNOSTIC_LIMIT = 4_000
  GENERATED_FILE_RUN_FILTERED_VALUE = "[FILTERED]"

  GENERATED_FILE_RUN_SENSITIVE_KEY_PATTERN =
    /(authorization|token|secret|password|api[_-]?key|access[_-]?token|refresh[_-]?token|client[_-]?secret|client[_-]?state)/i
  GENERATED_FILE_RUN_SENSITIVE_ASSIGNMENT_PATTERN =
    /\b(authorization|token|secret|password|api[_-]?key|access[_-]?token|refresh[_-]?token|client[_-]?secret|client[_-]?state)\b\s*[:=]\s*["']?[^"'\s,;}]+/i
  GENERATED_FILE_RUN_BEARER_TOKEN_PATTERN = /\bBearer\s+[A-Za-z0-9._~+\/-]+=*/i
  GENERATED_FILE_RUN_PRIVATE_PATH_PATTERN = %r{\b[A-Za-z]:[\\/][^\s<>"']+|/(?:Users|home|var|tmp|private|srv|app|workspace)/[^\s<>"']+}

  def generated_file_run_diagnostic_preview(value)
    text = mask_generated_file_run_diagnostic_value(value.to_s)
    return "-" if text.blank?

    truncate(text, length: GENERATED_FILE_RUN_DIAGNOSTIC_LIMIT, omission: "...")
  end

  def generated_file_run_metadata_preview(metadata)
    JSON.pretty_generate(mask_generated_file_run_metadata(metadata || {}))
  end

  private

  def mask_generated_file_run_metadata(value, key: nil)
    if key.to_s.match?(GENERATED_FILE_RUN_SENSITIVE_KEY_PATTERN)
      GENERATED_FILE_RUN_FILTERED_VALUE
    elsif value.is_a?(Hash)
      value.each_with_object({}) do |(child_key, child_value), result|
        result[child_key] = mask_generated_file_run_metadata(child_value, key: child_key)
      end
    elsif value.is_a?(Array)
      value.map { |child_value| mask_generated_file_run_metadata(child_value, key:) }
    elsif value.is_a?(String)
      mask_generated_file_run_diagnostic_value(value)
    else
      value
    end
  end

  def mask_generated_file_run_diagnostic_value(value)
    value.to_s
      .gsub(GENERATED_FILE_RUN_BEARER_TOKEN_PATTERN, "Bearer #{GENERATED_FILE_RUN_FILTERED_VALUE}")
      .gsub(GENERATED_FILE_RUN_SENSITIVE_ASSIGNMENT_PATTERN) { "#{Regexp.last_match(1)}=#{GENERATED_FILE_RUN_FILTERED_VALUE}" }
      .gsub(GENERATED_FILE_RUN_PRIVATE_PATH_PATTERN, GENERATED_FILE_RUN_FILTERED_VALUE)
  end
end
