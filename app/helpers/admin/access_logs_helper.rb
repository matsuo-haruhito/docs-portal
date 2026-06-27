# frozen_string_literal: true

module Admin::AccessLogsHelper
  AI_CONTEXT_TARGET_KEYS = %w[mode scope selected_count exported_count].freeze
  AI_CONTEXT_MODE_FILTER_OPTIONS = %w[compact full].freeze
  AI_CONTEXT_MODE_FILTER_LABELS = {
    "compact" => "コンパクト",
    "full" => "詳細"
  }.freeze
  AI_CONTEXT_SCOPE_FILTER_LABELS = {
    "all" => "全件",
    "selected" => "選択"
  }.freeze
  AI_CONTEXT_TARGET_DETAIL_LABELS = {
    "mode" => "AI出力モード",
    "scope" => "AI出力範囲",
    "selected_count" => "選択数",
    "scoped_count" => "案件内候補",
    "exported_count" => "出力数"
  }.freeze
  ACCESS_LOG_DATE_FILTER_LABELS = {
    from: "開始日",
    to: "終了日"
  }.freeze
  AUTHORIZATION_TARGET_VALUE_PATTERN = /\bAuthorization:\s*(?:Bearer|Basic)\s+[^;\s]+/i
  AUTHORIZATION_TARGET_PARAM_PATTERN = /\bauthorization\s*=\s*((?:Bearer|Basic)\s+)?[^;&\s]+/i
  AUTH_SCHEME_TARGET_VALUE_PATTERN = /\b(Bearer|Basic)\s+[^;\s]+/i
  SENSITIVE_TARGET_KEY_PATTERN = /\b(token|secret|password|client_secret|access_token|refresh_token|api[_-]?key)\s*([=:])\s*([^;&\s]+)/i
  SENSITIVE_TARGET_QUERY_PATTERN = /([?&](?:authorization|token|secret|password|client_secret|access_token|refresh_token|api[_-]?key)=)([^&#\s]+)/i
  PRIVATE_PATH_PATTERN = %r{(?:[A-Za-z]:[\\/]|/(?:Users|home)/)[^;\s]+}

  def access_log_table_columns
    [
      table_preferences_column(:accessed_at, label: "日時", default_width: 170, pinned: true, sortable: true),
      table_preferences_column(:action_type, label: "操作", default_width: 120),
      table_preferences_column(:target, label: "対象", default_width: 220, overflow: :ellipsis),
      table_preferences_column(:user, label: "ユーザー", default_width: 220, overflow: :ellipsis),
      table_preferences_column(:company, label: "会社", default_width: 180, overflow: :ellipsis),
      table_preferences_column(:project, label: "案件", default_width: 180, overflow: :ellipsis),
      table_preferences_column(:document, label: "文書", default_width: 220, overflow: :ellipsis),
      table_preferences_column(:document_version, label: "版", default_width: 180, overflow: :ellipsis),
      table_preferences_column(:ip_address, label: "IPアドレス", default_width: 150)
    ]
  end

  def access_log_target_type_filter_options
    enum_options_for("access_logs.target_type", AccessLog::TARGET_TYPE_FILTERS)
  end

  def access_log_ai_context_mode_filter_options
    AI_CONTEXT_MODE_FILTER_OPTIONS.map { |value| [access_log_ai_context_mode_filter_label(value), value] }
  end

  def access_log_ai_context_scope_filter_options
    AI_CONTEXT_SCOPE_FILTER_LABELS.map { |value, label| [label, value] }
  end

  def access_log_ignored_date_filter_label(filters)
    Array(filters).map do |filter|
      ACCESS_LOG_DATE_FILTER_LABELS.fetch(filter.to_sym, filter.to_s)
    end.join("、")
  end

  def access_log_filter_select_html_options(placeholder:)
    {
      data: {
        controller: "rails-fields-kit--tom-select",
        rails_fields_kit__tom_select_kind_value: "select",
        rails_fields_kit__tom_select_placeholder_value: placeholder,
        rails_fields_kit__tom_select_plugins_value: ["clear_button"]
      }
    }
  end

  def access_log_project_filter_options(projects)
    projects.map { [access_log_project_filter_label(_1), _1.id] }
  end

  def access_log_company_filter_options(companies)
    companies.map do |company|
      [access_log_company_filter_label(company), company.id]
    end
  end

  def access_log_user_filter_options(users)
    users.map do |user|
      [access_log_user_filter_label(user), user.id]
    end
  end

  def access_log_project_selected_option(project)
    return if project.blank?

    { value: project.id, text: access_log_project_filter_label(project) }
  end

  def access_log_company_selected_option(company)
    return if company.blank?

    { value: company.id, text: access_log_company_filter_label(company) }
  end

  def access_log_user_selected_option(user)
    return if user.blank?

    { value: user.id, text: access_log_user_filter_label(user) }
  end

  def access_log_active_filter_summaries(filters, projects:, companies:, users:)
    filters = filters.to_h.with_indifferent_access

    [
      access_log_enum_filter_summary("操作", filters[:action_type], "access_logs.action_type", AccessLog.action_types.keys),
      access_log_enum_filter_summary("対象種別", filters[:target_type], "access_logs.target_type", AccessLog::TARGET_TYPE_FILTERS),
      access_log_ai_context_mode_filter_summary(filters[:ai_context_mode]),
      access_log_ai_context_scope_filter_summary(filters[:ai_context_scope]),
      access_log_record_filter_summary("案件", filters[:project_id], projects) { access_log_project_filter_label(_1) },
      access_log_record_filter_summary("会社", filters[:company_id], companies) { access_log_company_filter_label(_1) },
      access_log_record_filter_summary("ユーザー", filters[:user_id], users) { access_log_user_filter_label(_1) },
      access_log_text_filter_summary("対象名・IPアドレス", filters[:q]),
      access_log_text_filter_summary("文書名・URL識別子", filters[:document_q]),
      access_log_date_filter_summary("開始日", filters[:from]),
      access_log_date_filter_summary("終了日", filters[:to])
    ].compact
  end

  def access_log_ai_context_target_details(log)
    return unless log.target_type.to_s == "ai_context"

    raw_target_name = log.target_name.to_s.strip
    return if raw_target_name.blank?

    values = parse_ai_context_target_name(raw_target_name)
    segments = []

    if values
      segments = [
        { label: AI_CONTEXT_TARGET_DETAIL_LABELS.fetch("mode"), value: access_log_ai_context_mode_filter_label(values.fetch("mode")) },
        { label: AI_CONTEXT_TARGET_DETAIL_LABELS.fetch("scope"), value: ai_context_scope_label(values.fetch("scope")) },
        { label: AI_CONTEXT_TARGET_DETAIL_LABELS.fetch("selected_count"), value: "#{values.fetch('selected_count')}件" }
      ]
      if values["scoped_count"].present?
        segments << { label: AI_CONTEXT_TARGET_DETAIL_LABELS.fetch("scoped_count"), value: "#{values.fetch('scoped_count')}件" }
      end
      segments << { label: AI_CONTEXT_TARGET_DETAIL_LABELS.fetch("exported_count"), value: "#{values.fetch('exported_count')}件" }
    end

    {
      preview: safe_access_log_target_name_preview(raw_target_name),
      segments:
    }
  end

  def access_log_company_secondary_label(company)
    return unless company

    domain = company.domain.presence
    return if domain.blank? || company.display_name == domain

    domain
  end

  def access_log_project_secondary_label(project)
    project&.code.presence
  end

  private

  def parse_ai_context_target_name(raw_target_name)
    pairs = raw_target_name.split(";").each_with_object({}) do |part, values|
      key, value = part.split("=", 2).map { _1.to_s.strip }
      return nil if key.blank? || value.blank?

      values[key] = value
    end

    return unless AI_CONTEXT_TARGET_KEYS.all? { pairs[_1].present? }
    return unless pairs["selected_count"].match?(/\A\d+\z/) && pairs["exported_count"].match?(/\A\d+\z/)
    if pairs["scoped_count"].present?
      return unless pairs["scoped_count"].match?(/\A\d+\z/)
    end

    pairs.slice(*(AI_CONTEXT_TARGET_KEYS + %w[scoped_count]))
  end

  def safe_access_log_target_name_preview(raw_target_name)
    raw_target_name.to_s.strip
      .gsub(AUTHORIZATION_TARGET_VALUE_PATTERN, "Authorization: [FILTERED]")
      .gsub(AUTHORIZATION_TARGET_PARAM_PATTERN) do
        Regexp.last_match(1).present? ? "authorization=[FILTERED] [FILTERED]" : "authorization=[FILTERED]"
      end
      .gsub(AUTH_SCHEME_TARGET_VALUE_PATTERN) { "#{Regexp.last_match(1)} [FILTERED]" }
      .gsub(SENSITIVE_TARGET_KEY_PATTERN) { "#{Regexp.last_match(1)}#{Regexp.last_match(2)}[FILTERED]" }
      .gsub(SENSITIVE_TARGET_QUERY_PATTERN) { "#{Regexp.last_match(1)}[FILTERED]" }
      .gsub(PRIVATE_PATH_PATTERN, "[path hidden]")
      .truncate(180)
  end

  def ai_context_scope_label(scope)
    case scope
    when "all"
      "全件"
    when "selected"
      "選択"
    else
      scope
    end
  end

  def access_log_enum_filter_summary(label, value, scope, known_values)
    return if value.blank?

    display = known_values.include?(value.to_s) ? localized_label(scope, value) : "指定あり"
    "#{label}: #{display}"
  end

  def access_log_ai_context_mode_filter_summary(value)
    return if value.blank? || AI_CONTEXT_MODE_FILTER_OPTIONS.exclude?(value.to_s)

    "AI出力モード: #{access_log_ai_context_mode_filter_label(value)}"
  end

  def access_log_ai_context_scope_filter_summary(value)
    return if value.blank?

    label = AI_CONTEXT_SCOPE_FILTER_LABELS[value.to_s]
    return unless label

    "AI出力範囲: #{label}"
  end

  def access_log_record_filter_summary(label, value, records)
    return if value.blank?

    record = records.find { _1.id.to_s == value.to_s }
    display = record ? yield(record) : "指定あり"
    "#{label}: #{display}"
  end

  def access_log_text_filter_summary(label, value)
    value = value.to_s.strip
    return if value.blank?

    "#{label}: #{value}"
  end

  def access_log_date_filter_summary(label, value)
    return if value.blank?

    date = Date.iso8601(value.to_s)
    "#{label}: #{date.strftime('%Y-%m-%d')}"
  rescue ArgumentError
    "#{label}: 日付を確認"
  end

  def access_log_ai_context_mode_filter_label(value)
    AI_CONTEXT_MODE_FILTER_LABELS.fetch(value.to_s, value.to_s)
  end

  def access_log_project_filter_label(project)
    [project.code.presence, project.name.presence].compact.join(" / ")
  end

  def access_log_company_filter_label(company)
    label = company.display_name
    label = "#{label} / #{company.domain}" if company.domain.present?
    label
  end

  def access_log_user_filter_label(user)
    primary_label = user.display_name.presence || user.email_address
    primary_label == user.email_address ? primary_label : "#{primary_label} / #{user.email_address}"
  end
end
