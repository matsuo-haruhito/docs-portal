# frozen_string_literal: true

module Admin::ExternalFolderSyncSourcesHelper
  LATEST_ERROR_PREVIEW_MAX_LENGTH = 120
  PRIVATE_PATH_PATTERN = %r{(?:(?<![A-Za-z])[A-Za-z]:[/\\]|/(?:Users|home|var|tmp|mnt|Volumes|workspace)/)[^\s;,]+}.freeze
  AUTHORIZATION_BEARER_PATTERN = /(\bauthorization\b\s*[:=]\s*)Bearer\s+[^\s&;,]+/i.freeze
  SENSITIVE_VALUE_PATTERN = /(\b(?:authorization|token|secret|password|client_secret|access_token|refresh_token)\b\s*[:=]\s*)([^\s&;,]+)/i.freeze
  SENSITIVE_QUERY_PATTERN = /([?&](?:token|secret|password|client_secret|access_token|refresh_token)=)([^&\s]+)/i.freeze

  def external_folder_sync_source_table_columns
    [
      table_preferences_column(:project, label: "対象案件", default_width: 220, pinned: true, overflow: :ellipsis),
      table_preferences_column(:name, label: "同期設定名", default_width: 220, overflow: :ellipsis, sortable: true),
      table_preferences_column(:provider, label: "連携先", default_width: 170),
      table_preferences_column(:external_folder_location, label: "外部フォルダID / path", default_width: 280, overflow: :ellipsis),
      table_preferences_column(:status, label: "同期状態", default_width: 110),
      table_preferences_column(:last_synced_at, label: "最終同期日時", default_width: 180, sortable: true),
      table_preferences_column(:latest_safety, label: "最新安全判定", default_width: 150),
      table_preferences_column(:warning_count, label: "競合・重複警告", default_width: 140),
      table_preferences_column(:latest_error, label: "最新エラー", default_width: 280, overflow: :ellipsis),
      table_preferences_column(:actions, label: "操作", default_width: 230, pinned: true)
    ]
  end

  def external_folder_sync_source_project_option_label(project)
    [project.code, project.name].compact_blank.join(" / ")
  end

  def external_folder_sync_source_project_selected_option(project)
    return nil if project.blank?

    { value: project.id, text: external_folder_sync_source_project_option_label(project) }
  end

  def external_folder_sync_latest_error_preview(message)
    preview = external_folder_sync_sanitized_error_message(message)
    return "-" if preview.blank?

    if preview.length > LATEST_ERROR_PREVIEW_MAX_LENGTH
      "#{preview.first(LATEST_ERROR_PREVIEW_MAX_LENGTH)}..."
    else
      preview
    end
  end

  def external_folder_sync_latest_run_context_label(run)
    return "直近runなし" if run.blank?

    started_at = run.started_at.present? ? l(run.started_at) : "時刻未記録"
    "直近run: #{started_at} / #{external_folder_sync_run_mode_label(run)} / #{external_folder_sync_run_status_label(run)}"
  end

  def external_folder_sync_latest_error_origin_label(run, source_last_error_message)
    return nil if run&.error_message.blank? && source_last_error_message.blank?

    run&.error_message.present? ? "由来: 直近run" : "由来: 同期元metadata"
  end

  def external_folder_sync_webhook_event_status_label(event_or_value)
    if event_or_value.respond_to?(:ignored_reason) && event_or_value.ignored_reason.present?
      return external_folder_sync_webhook_ignored_reason_label(event_or_value.ignored_reason)
    end

    value = event_or_value.respond_to?(:status) ? event_or_value.status : event_or_value
    localized_label("external_folder_sync_webhook_events.status", value)
  end

  def external_folder_sync_webhook_ignored_reason_label(reason)
    case reason.to_s
    when "coalesced_running"
      "無視（実行中のため集約）"
    when "coalesced_recent"
      "無視（登録済みジョブへ集約）"
    when "source_unavailable"
      "無視（同期元なし / 無効）"
    else
      "無視（要確認）"
    end
  end

  def external_folder_sync_graph_notification(event)
    Array(event.payload_json&.fetch("value", nil)).first || {}
  end

  def external_folder_sync_graph_notification_value(event, key)
    external_folder_sync_graph_notification(event).fetch(key.to_s, nil).presence || "-"
  end

  def external_folder_sync_sanitized_webhook_payload(event)
    sanitize_external_folder_sync_webhook_value(event.payload_json || {})
  end

  def external_folder_sync_display_event_key(event)
    event_key = event.event_key.presence
    return "-" if event_key.blank?
    return event_key unless event.sharepoint?

    client_state = external_folder_sync_graph_notification_value(event, "clientState")
    client_state == "-" ? event_key : event_key.gsub(client_state, "[masked]")
  end

  private

  def external_folder_sync_sanitized_error_message(message)
    message.to_s.squish
      .gsub(AUTHORIZATION_BEARER_PATTERN, "\\1[masked]")
      .gsub(SENSITIVE_VALUE_PATTERN, "\\1[masked]")
      .gsub(SENSITIVE_QUERY_PATTERN, "\\1[masked]")
      .gsub(PRIVATE_PATH_PATTERN, "[path hidden]")
  end

  def sanitize_external_folder_sync_webhook_value(value)
    case value
    when Hash
      value.each_with_object({}) do |(key, nested_value), sanitized|
        sanitized[key] = key.to_s == "clientState" ? "[masked]" : sanitize_external_folder_sync_webhook_value(nested_value)
      end
    when Array
      value.map { |nested_value| sanitize_external_folder_sync_webhook_value(nested_value) }
    else
      value
    end
  end
end
