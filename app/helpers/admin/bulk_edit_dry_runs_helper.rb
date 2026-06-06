module Admin::BulkEditDryRunsHelper
  BULK_EDIT_DRY_RUN_DIAGNOSTIC_PREVIEW_LENGTH = 120
  BULK_EDIT_DRY_RUN_SENSITIVE_KEY_PATTERN = /\b(?:access_token|refresh_token|client_secret|authorization|password|secret|token)\b/i
  BULK_EDIT_DRY_RUN_PRIVATE_PATH_PATTERN = %r{(?:[A-Za-z]:[\\/](?:Users|Documents and Settings)[\\/][^\s,;]+|/(?:Users|home)/[^\s,;]+)}

  def bulk_edit_dry_run_diagnostic_preview(value)
    text = value.to_s.squish
    return "-" if text.blank?

    preview = mask_bulk_edit_dry_run_diagnostic_text(text)
    truncate_bulk_edit_dry_run_diagnostic_preview(preview)
  end

  def bulk_edit_dry_run_diagnostic_list_preview(values)
    previews = Array(values).filter_map do |value|
      preview = bulk_edit_dry_run_diagnostic_preview(value)
      preview unless preview == "-"
    end

    previews.join(" / ").presence || "-"
  end

  private

  def mask_bulk_edit_dry_run_diagnostic_text(text)
    text
      .gsub(/Authorization:\s*Bearer\s+[^\s,;]+/i, "Authorization: [masked]")
      .gsub(/\bBearer\s+[^\s,;]+/i, "Bearer [masked]")
      .gsub(/\b(#{BULK_EDIT_DRY_RUN_SENSITIVE_KEY_PATTERN.source})\b\s*[:=]\s*(?!\[masked\])[^\s,;&]+/i) { "#{$1}=[masked]" }
      .gsub(/([?&])(#{BULK_EDIT_DRY_RUN_SENSITIVE_KEY_PATTERN.source})=(?!\[masked\])[^\s&#]+/i) { "#{$1}#{$2}=[masked]" }
      .gsub(BULK_EDIT_DRY_RUN_PRIVATE_PATH_PATTERN, "[path hidden]")
  end

  def truncate_bulk_edit_dry_run_diagnostic_preview(text)
    return text if text.length <= BULK_EDIT_DRY_RUN_DIAGNOSTIC_PREVIEW_LENGTH

    "#{text.first(BULK_EDIT_DRY_RUN_DIAGNOSTIC_PREVIEW_LENGTH - 3)}..."
  end
end
