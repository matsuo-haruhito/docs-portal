# frozen_string_literal: true

module Admin::ReadConfirmationsHelper
  def read_confirmation_table_columns
    [
      table_preferences_column(:confirmed_at, label: "確認日時", default_width: 170, pinned: true, sortable: true),
      table_preferences_column(:document, label: "文書", default_width: 220, pinned: true, overflow: :ellipsis),
      table_preferences_column(:user, label: "確認者", default_width: 220, overflow: :ellipsis),
      table_preferences_column(:company, label: "会社", default_width: 180, overflow: :ellipsis),
      table_preferences_column(:document_slug, label: "文書URL識別子", default_width: 170, overflow: :ellipsis)
    ]
  end
end
