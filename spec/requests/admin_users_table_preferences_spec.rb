# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin users table preferences", type: :request do
  TABLE_COLUMN_KEYS = %w[
    name
    email_address
    display_name
    user_type
    company
    status
    actions
  ].freeze

  it "renders the table preferences editor and stable user table columns" do
    admin = create(:user, :internal, name: "Admin User", email_address: "admin-users-smoke@example.com", company: nil)
    company = create(:company, name: "Smoke Company")
    create(
      :user,
      :external,
      name: "Smoke External User",
      email_address: "external-users-smoke@example.com",
      company:,
      active: false
    )

    sign_in_as(admin)

    get admin_users_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("ユーザー一覧の表示設定")
    expect(response.body).to include("ユーザー名（表示用）", "メールアドレス", "表示名", "種別", "会社", "状態")
    expect(response.body).to include("Smoke External User")
    expect(response.body).to include("external-users-smoke@example.com")
    expect(response.body).to include("Smoke Company")
    expect(response.body).to include("無効")
    expect(response.body).to include("編集", "削除")

    TABLE_COLUMN_KEYS.each do |column_key|
      expect(response.body).to include(%(data-rails-table-preferences-column-key="#{column_key}"))
    end
  end

  it "keeps the source contract for the table key, columns, and empty state" do
    view_source = Rails.root.join("app/views/admin/users/index.html.slim").read
    helper_source = Rails.root.join("app/helpers/admin/users_helper.rb").read

    expect(view_source).to include("- table_key = :admin_users")
    expect(view_source).to include("table_preferences_editor(table_key: table_key")
    expect(view_source).to include("table_preferences_table_tag(table_key: table_key")

    TABLE_COLUMN_KEYS.each do |column_key|
      expect(helper_source).to include("table_preferences_column(:#{column_key}")
      expect(view_source).to include(%(data-rails-table-preferences-column-key="#{column_key}"))
    end
    expect(helper_source).to include("table_preferences_column(:actions, label: \"操作\", default_width: 180, pinned: true)")

    empty_state_source = view_source[view_source.index("- else")..]
    expect(empty_state_source).to include("section.card")
    expect(empty_state_source).to include("まだ表示中の範囲にユーザーは登録されていません。")
    expect(empty_state_source).not_to include("table_preferences_editor")
    expect(empty_state_source).not_to include("table_preferences_table_tag")
  end
end
