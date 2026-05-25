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
end
