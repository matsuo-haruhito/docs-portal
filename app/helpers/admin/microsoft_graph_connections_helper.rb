# frozen_string_literal: true

module Admin::MicrosoftGraphConnectionsHelper
  GRAPH_IDENTIFIER_PREVIEW_PREFIX_LENGTH = 10
  GRAPH_IDENTIFIER_PREVIEW_SUFFIX_LENGTH = 8
  GRAPH_IDENTIFIER_PREVIEW_MAX_LENGTH = 28
  GRAPH_PRIVATE_PATH_PATTERN = %r{(?:(?<![A-Za-z])[A-Za-z]:[/\\]|/(?:Users|home|var|tmp|mnt|Volumes|workspace)/)[^\s;,]+}.freeze
  GRAPH_AUTHORIZATION_BEARER_PATTERN = /(\bauthorization\b\s*[:=]\s*)Bearer\s+[^\s&;,]+/i.freeze
  GRAPH_SENSITIVE_VALUE_PATTERN = /(\b(?:authorization|token|secret|password|client_secret|access_token|refresh_token)\b\s*[:=]\s*)([^\s&;,]+)/i.freeze
  GRAPH_SENSITIVE_QUERY_PATTERN = /([?&](?:token|secret|password|client_secret|access_token|refresh_token)=)([^&\s]+)/i.freeze

  def microsoft_graph_connection_table_columns
    [
      table_preferences_column(:project, label: "案件", default_width: 220, pinned: true, overflow: :ellipsis),
      table_preferences_column(:name, label: "接続名", default_width: 200, overflow: :ellipsis, sortable: true),
      table_preferences_column(:graph_identifiers, label: "Tenant / Client / Site", default_width: 280, overflow: :ellipsis),
      table_preferences_column(:drive, label: "Drive", default_width: 260, overflow: :ellipsis),
      table_preferences_column(:preview_folder, label: "プレビュー用フォルダ", default_width: 260, overflow: :ellipsis),
      table_preferences_column(:status, label: "状態", default_width: 110),
      table_preferences_column(:preview_usage, label: "preview利用", default_width: 220),
      table_preferences_column(:actions, label: "操作", default_width: 230, pinned: true)
    ]
  end

  def microsoft_graph_connection_identifier_preview(value)
    preview = microsoft_graph_connection_sanitized_identifier(value)
    return "-" if preview.blank?
    return preview if preview.length <= GRAPH_IDENTIFIER_PREVIEW_MAX_LENGTH

    "#{preview.first(GRAPH_IDENTIFIER_PREVIEW_PREFIX_LENGTH)}...#{preview.last(GRAPH_IDENTIFIER_PREVIEW_SUFFIX_LENGTH)}"
  end

  private

  def microsoft_graph_connection_sanitized_identifier(value)
    value.to_s.squish
      .gsub(GRAPH_AUTHORIZATION_BEARER_PATTERN, "\\1[masked]")
      .gsub(GRAPH_SENSITIVE_VALUE_PATTERN, "\\1[masked]")
      .gsub(GRAPH_SENSITIVE_QUERY_PATTERN, "\\1[masked]")
      .gsub(GRAPH_PRIVATE_PATH_PATTERN, "[path hidden]")
  end
end
