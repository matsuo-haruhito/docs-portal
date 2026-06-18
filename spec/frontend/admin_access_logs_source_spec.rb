require "rails_helper"

RSpec.describe "admin access logs source" do
  let(:view_source) { Rails.root.join("app/views/admin/access_logs/index.html.slim").read }
  let(:helper_source) { Rails.root.join("app/helpers/admin/access_logs_helper.rb").read }

  it "uses remote rails fields kit comboboxes for project, company, and user filters" do
    aggregate_failures do
      expect(view_source).to include("= form.rfk_combobox :project_id,")
      expect(view_source).to include("selected: access_log_project_selected_option(@selected_project)")
      expect(view_source).to include("url: project_search_admin_access_logs_path(format: :json)")
      expect(view_source).to include("selected_url: selected_project_admin_access_logs_path(format: :json)")
      expect(view_source).to include('placeholder: "案件コード・案件名で検索"')
      expect(view_source).to include("= form.rfk_combobox :company_id,")
      expect(view_source).to include("selected: access_log_company_selected_option(@selected_company)")
      expect(view_source).to include("url: company_search_admin_access_logs_path(format: :json)")
      expect(view_source).to include("selected_url: selected_company_admin_access_logs_path(format: :json)")
      expect(view_source).to include('placeholder: "会社名・ドメインで検索"')
      expect(view_source).to include("= form.rfk_combobox :user_id,")
      expect(view_source).to include("selected: access_log_user_selected_option(@selected_user)")
      expect(view_source).to include("url: user_search_admin_access_logs_path(format: :json)")
      expect(view_source).to include("selected_url: selected_user_admin_access_logs_path(format: :json)")
      expect(view_source).to include('placeholder: "ユーザー名・メールアドレスで検索"')
      expect(view_source).not_to include("= select_tag :project_id,")
      expect(view_source).not_to include("= select_tag :company_id,")
      expect(view_source).not_to include("= select_tag :user_id,")
      expect(view_source).not_to include("= form.select :project_id")
      expect(view_source).not_to include("= form.select :company_id")
      expect(view_source).not_to include("= form.select :user_id")
    end
  end

  it "wires the access log table through rails table preferences metadata" do
    aggregate_failures do
      expect(view_source).to include("table_preferences_editor(table_key: table_key, settings: table_settings, columns: table_columns, title: \"監査ログ一覧の表示設定\")")
      expect(view_source).to include("table_preferences_table_tag(table_key: table_key, settings: table_settings, columns: table_columns)")
      expect(view_source).to include('data-rails-table-preferences-column-key="accessed_at"')
      expect(view_source).to include('data-rails-table-preferences-column-key="action_type"')
      expect(view_source).to include('data-rails-table-preferences-column-key="target"')
      expect(view_source).to include('data-rails-table-preferences-column-key="user"')
      expect(view_source).to include('data-rails-table-preferences-column-key="company"')
      expect(view_source).to include('data-rails-table-preferences-column-key="project"')
      expect(view_source).to include('data-rails-table-preferences-column-key="document"')
      expect(view_source).to include('data-rails-table-preferences-column-key="document_version"')
      expect(view_source).to include('data-rails-table-preferences-column-key="ip_address"')
      expect(view_source).not_to include("table\n  thead")
    end
  end

  it "keeps the column metadata and tom select wiring in the helper" do
    aggregate_failures do
      expect(helper_source).to include("def access_log_table_columns")
      expect(helper_source).to include('table_preferences_column(:accessed_at, label: "日時"')
      expect(helper_source).to include('table_preferences_column(:document_version, label: "版"')
      expect(helper_source).to include('table_preferences_column(:ip_address, label: "IPアドレス"')
      expect(helper_source).to include("def access_log_filter_select_html_options(placeholder:)")
      expect(helper_source).to include('controller: "rails-fields-kit--tom-select"')
      expect(helper_source).to include('rails_fields_kit__tom_select_placeholder_value: placeholder')
      expect(helper_source).to include('rails_fields_kit__tom_select_plugins_value: ["clear_button"]')
      expect(helper_source).to include("def access_log_project_selected_option(project)")
      expect(helper_source).to include("def access_log_company_selected_option(company)")
      expect(helper_source).to include("def access_log_user_selected_option(user)")
    end
  end
end
