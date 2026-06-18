# frozen_string_literal: true

module Admin::ProjectConsentSettingsHelper
  def project_consent_setting_table_columns
    [
      table_preferences_column(:project, label: "案件", default_width: 220, pinned: true, sortable: true),
      table_preferences_column(:consent_term, label: "同意文面", default_width: 260, overflow: :ellipsis, sortable: true),
      table_preferences_column(:version_label, label: "版", default_width: 120, sortable: true),
      table_preferences_column(:required_on, label: "必須タイミング", default_width: 160),
      table_preferences_column(:enabled, label: "状態", default_width: 100),
      table_preferences_column(:actions, label: "操作", default_width: 150, pinned: true)
    ]
  end

  def project_consent_setting_project_option_label(project)
    "#{project.name} (#{project.code})"
  end

  def project_consent_setting_project_selected_option(project)
    return nil if project.blank?

    { value: project.id, text: project_consent_setting_project_option_label(project) }
  end

  def project_consent_term_option_label(term)
    "#{term.title} / #{term.version_label}"
  end

  def project_consent_term_selected_option(term)
    return nil if term.blank?

    { value: term.id, text: project_consent_term_option_label(term) }
  end

  def project_consent_setting_required_on_label(required_on)
    case required_on.to_s
    when "first_access"
      "閲覧前"
    when "download"
      "ダウンロード前"
    when "shared_link_access"
      "共有リンク閲覧前（予約）"
    when "shared_link_download"
      "共有リンクダウンロード前（予約）"
    else
      required_on.to_s
    end
  end

  def project_consent_setting_required_on_options
    ProjectConsentSetting.required_ons.keys.map do |required_on|
      [project_consent_setting_required_on_label(required_on), required_on]
    end
  end

  def project_consent_settings_handoff_summary(settings:, selected_project:, selected_consent_term:, selected_enabled:, pagination:, filtered_count:)
    lines = [
      "案件同意設定 handoff summary",
      "",
      "条件:",
      "- 案件: #{selected_project ? project_consent_setting_project_option_label(selected_project) : "すべて"}",
      "- 同意文面: #{selected_consent_term ? project_consent_term_option_label(selected_consent_term) : "すべて"}",
      "- 状態: #{project_consent_settings_handoff_enabled_label(selected_enabled)}",
      "- 件数: 検索結果 #{filtered_count.to_i}件 / 表示中 #{project_consent_settings_handoff_range_label(pagination, filtered_count)}",
      "- 対象範囲: 現在の表示ページのみ。table preferences は表示設定であり、handoff 条件ではありません。",
      "",
      "表示中設定:"
    ]

    if settings.blank?
      lines << "- なし"
    else
      settings.each_with_index do |setting, index|
        lines << "- #{index + 1}. #{project_consent_settings_handoff_row_label(setting)}"
      end
    end

    lines.concat([
      "",
      "注意:",
      "- 共有リンク閲覧前（予約）/共有リンクダウンロード前（予約）は将来拡張用で、現時点の共有リンク同意 enforcement を意味しません。",
      "- 同意本文、利用者同意履歴、個人情報、CSV一括 export は含みません。"
    ])

    lines.join("\n")
  end

  private

  def project_consent_settings_handoff_enabled_label(selected_enabled)
    case selected_enabled.to_s
    when "true"
      "有効"
    when "false"
      "無効"
    else
      "すべて"
    end
  end

  def project_consent_settings_handoff_range_label(pagination, filtered_count)
    return "0件" if filtered_count.to_i.zero?

    "#{pagination[:from]}-#{pagination[:to]}件 / #{filtered_count.to_i}件"
  end

  def project_consent_settings_handoff_row_label(setting)
    [
      project_consent_setting_project_option_label(setting.project),
      project_consent_term_option_label(setting.consent_term),
      project_consent_setting_required_on_label(setting.required_on),
      setting.enabled? ? "有効" : "無効"
    ].join(" / ")
  end
end
