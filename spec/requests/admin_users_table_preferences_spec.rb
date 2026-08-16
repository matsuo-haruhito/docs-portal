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

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def table_root
    parsed_html.at_css('table[data-rails-table-preferences-table-key-value="admin_users"]')
  end

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
    expect(table_root).to be_present
    expect(parsed_html.text.squish).to include("Smoke External User", "external-users-smoke@example.com", "Smoke Company")

    TABLE_COLUMN_KEYS.each do |column_key|
      expect(table_root.css(%([data-rails-table-preferences-column-key="#{column_key}"]))).to be_present,
        "missing RTP column key: #{column_key}"
    end
  end

  it "keeps the table key and column source contract while omitting RTP surfaces for empty filtered results" do
    admin = create(:user, :internal, email_address: "admin-users-empty@example.com")
    view_source = Rails.root.join("app/views/admin/users/index.html.slim").read
    helper_source = Rails.root.join("app/helpers/admin/users_helper.rb").read

    expect(view_source).to include("- table_key = :admin_users")
    expect(view_source).to include("render ColumnSettingsComponent.new(table_key: table_key")
    expect(view_source).to include("table_preferences_table_tag(table_key: table_key")

    TABLE_COLUMN_KEYS.each do |column_key|
      expect(helper_source).to include("table_preferences_column(:#{column_key}")
      expect(view_source).to include(%(data-rails-table-preferences-column-key="#{column_key}"))
    end
    expect(helper_source).to include('table_preferences_column(:name, label: "登録氏名", default_visible: false, overflow: :ellipsis)')
    expect(helper_source).to include('table_preferences_column(:display_name, label: "画面表示名", default_visible: true, overflow: :ellipsis)')
    expect(helper_source).to include('table_preferences_column(:actions, label: "操作", default_width: 100, pinned: true)')

    sign_in_as(admin)
    get admin_users_path, params: { q: "no-matching-user" }

    expect(response).to have_http_status(:ok)
    expect(parsed_html.at_css(".empty-state")).to be_present
    expect(table_root).to be_nil
  end
end
