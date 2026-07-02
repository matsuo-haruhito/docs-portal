module Admin::GeneratedFileRunsHelper
  GENERATED_FILE_RUN_DIAGNOSTIC_LIMIT = 4_000
  GENERATED_FILE_RUN_SEARCH_HINT_LIMIT = 4
  GENERATED_FILE_RUN_SEARCH_HINT_VALUE_LIMIT = 100
  GENERATED_FILE_RUN_FILTERED_VALUE = "[FILTERED]"

  GENERATED_FILE_RUN_SENSITIVE_KEY_PATTERN =
    /(authorization|token|secret|password|api[_-]?key|access[_-]?token|refresh[_-]?token|client[_-]?secret|client[_-]?state)/i
  GENERATED_FILE_RUN_SENSITIVE_ASSIGNMENT_PATTERN =
    /\b(authorization|token|secret|password|api[_-]?key|access[_-]?token|refresh[_-]?token|client[_-]?secret|client[_-]?state)\b\s*[:=]\s*["']?[^"'\s,;}]+/i
  GENERATED_FILE_RUN_BEARER_TOKEN_PATTERN = /\bBearer\s+[A-Za-z0-9._~+\/-]+=*/i
  GENERATED_FILE_RUN_PRIVATE_PATH_PATTERN = %r{\b[A-Za-z]:[\\/][^\s<>"']+|/(?:Users|home|var|tmp|private|srv|app|workspace)/[^\s<>"']+}

  def generated_file_run_bulk_retry_scope_copy(filters)
    return "すべての失敗履歴から古い順に最大100件を対象にします。" if filters.compact_blank.blank?

    "現在の絞り込み条件に一致する失敗履歴から古い順に最大100件を対象にします。"
  end

  def generated_file_run_bulk_retry_filter_summary(filters)
    normalized_filters = filters.compact_blank
    return [] if normalized_filters.blank?

    [
      generated_file_run_filter_summary_item("状態", generated_file_run_status_summary_value(normalized_filters[:status])),
      generated_file_run_filter_summary_item("ジョブID", normalized_filters[:job_id]),
      generated_file_run_filter_summary_item("ジェネレーター", normalized_filters[:generator]),
      generated_file_run_filter_summary_item("出力先", normalized_filters[:output_writer]),
      generated_file_run_filter_summary_item("イベント発生元", generated_file_source_label(normalized_filters[:event_source])),
      generated_file_run_filter_summary_item("作成日", generated_file_run_date_filter_summary(normalized_filters)),
      generated_file_run_filter_summary_item("検索語", normalized_filters[:q])
    ].compact
  end

  def generated_file_run_diagnostic_preview(value)
    text = mask_generated_file_run_diagnostic_value(value.to_s)
    return "-" if text.blank?

    truncate(text, length: GENERATED_FILE_RUN_DIAGNOSTIC_LIMIT, omission: "...")
  end

  def generated_file_run_metadata_preview(metadata)
    JSON.pretty_generate(mask_generated_file_run_metadata(metadata || {}))
  end

  def generated_file_run_search_hints(run)
    hints = []
    append_generated_file_run_search_hint(hints, "実行ID", run.public_id)
    append_generated_file_run_search_hint(hints, "ジョブID", run.job_id)

    Array(run.metadata&.dig("generated_file_event_public_ids")).compact_blank.uniq.each do |public_id|
      append_generated_file_run_search_hint(hints, "関連イベントID", public_id)
    end

    generated_file_run_path_hint_values(run).each do |path_hint|
      append_generated_file_run_search_hint(hints, "パス断片", path_hint)
    end

    append_generated_file_run_search_hint(hints, "エラー断片", generated_file_run_error_search_fragment(run.error_message))
    hints.first(GENERATED_FILE_RUN_SEARCH_HINT_LIMIT)
  end

  def generated_file_run_retry_kind_label(run)
    metadata = run.metadata || {}
    bulk_retry = metadata["bulk_retry"]

    if run.event_source == "generated_file_run_bulk_retry" || bulk_retry == true || bulk_retry.to_s == "true"
      "一括再実行"
    elsif run.event_source == "generated_file_run_retry" || metadata.key?("retry_of_generated_file_run_public_id")
      "再実行"
    else
      "-"
    end
  end

  def generated_file_run_retry_requester_label(user_id, user)
    return "-" if user_id.blank?
    return "#{user.name} (#{user.email_address})" if user

    "ユーザーID #{user_id}（未検出）"
  end

  private

  def generated_file_run_filter_summary_item(label, value)
    text = value.to_s.squish
    return if text.blank? || text == "-"

    "#{label}: #{text}"
  end

  def generated_file_run_status_summary_value(status)
    return if status.blank?

    generated_file_run_status_label(status)
  end

  def generated_file_run_date_filter_summary(filters)
    from = filters[:created_from].presence
    to = filters[:created_to].presence
    return if from.blank? && to.blank?
    return "#{from}以降" if to.blank?
    return "#{to}まで" if from.blank?

    "#{from}〜#{to}"
  end

  def append_generated_file_run_search_hint(hints, label, value)
    safe_value = generated_file_run_safe_search_hint_value(value)
    return if safe_value.blank?
    return if hints.any? { |hint| hint[:value].casecmp?(safe_value) }

    hints << {label:, value: safe_value}
  end

  def generated_file_run_path_hint_values(run)
    Array(run.source_paths) + Array(run.changed_files) + Array(run.generated_paths)
      .map { |path| File.basename(path.to_s) }
      .reject { |path| path.blank? || path == "." }
      .uniq
  end

  def generated_file_run_error_search_fragment(error_message)
    masked_text = mask_generated_file_run_diagnostic_value(error_message.to_s).squish
    return if masked_text.blank? || masked_text.include?(GENERATED_FILE_RUN_FILTERED_VALUE)

    masked_text
  end

  def generated_file_run_safe_search_hint_value(value)
    text = value.to_s.squish
    return if text.blank?
    return if text.match?(GENERATED_FILE_RUN_SENSITIVE_KEY_PATTERN)

    masked_text = mask_generated_file_run_diagnostic_value(text).squish
    return if masked_text.blank? || masked_text.include?(GENERATED_FILE_RUN_FILTERED_VALUE)

    masked_text.first(GENERATED_FILE_RUN_SEARCH_HINT_VALUE_LIMIT)
  end

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
