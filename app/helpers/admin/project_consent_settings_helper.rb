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

  def project_consent_term_option_label(term)
    "#{term.title} / #{term.version_label}"
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
end
