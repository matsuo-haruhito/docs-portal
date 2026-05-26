require "rails_helper"

RSpec.describe "admin document permissions source" do
  let(:form_source) { Rails.root.join("app/views/admin/document_permissions/_form.html.slim").read }
  let(:index_source) { Rails.root.join("app/views/admin/document_permissions/index.html.slim").read }
  let(:helper_source) { Rails.root.join("app/helpers/admin/document_permissions_helper.rb").read }

  it "uses searchable rails fields kit selects for document, company, and user fields" do
    aggregate_failures do
      expect(form_source).to include("= form.rfk_select :document_id,")
      expect(form_source).to include("document_permission_form_document_options(@documents)")
      expect(form_source).to include('placeholder: "文書を選択"')
      expect(form_source).to include("= form.rfk_select :company_id,")
      expect(form_source).to include("document_permission_form_company_options(@companies)")
      expect(form_source).to include('placeholder: "会社向けに付与する場合に選択"')
      expect(form_source).to include("= form.rfk_select :user_id,")
      expect(form_source).to include("document_permission_form_user_options(@users)")
      expect(form_source).to include('placeholder: "ユーザー向けに付与する場合に選択"')
      expect(form_source).to include("allow_clear: true")
      expect(form_source).not_to include("form.collection_select :document_id")
      expect(form_source).not_to include("form.collection_select :company_id")
      expect(form_source).not_to include("form.collection_select :user_id")
    end
  end

  it "wires both admin document permission tables through rails table preferences" do
    aggregate_failures do
      expect(index_source).to include("overview_table_key = :admin_document_permission_overview")
      expect(index_source).to include("permissions_table_key = :admin_document_permissions")
      expect(index_source).to include('table_preferences_editor(table_key: overview_table_key, settings: overview_table_settings, columns: overview_table_columns, title: "権限概要の表示設定")')
      expect(index_source).to include('table_preferences_editor(table_key: permissions_table_key, settings: permissions_table_settings, columns: permissions_table_columns, title: "権限一覧の表示設定")')
      expect(index_source).to include("table_preferences_table_tag(table_key: overview_table_key, settings: overview_table_settings, columns: overview_table_columns)")
      expect(index_source).to include("table_preferences_table_tag(table_key: permissions_table_key, settings: permissions_table_settings, columns: permissions_table_columns)")
      expect(index_source).to include('data-rails-table-preferences-column-key="document"')
      expect(index_source).to include('data-rails-table-preferences-column-key="visibility_policy"')
      expect(index_source).to include('data-rails-table-preferences-column-key="company"')
      expect(index_source).to include('data-rails-table-preferences-column-key="user"')
      expect(index_source).to include('data-rails-table-preferences-column-key="access_level"')
      expect(index_source).to include('data-rails-table-preferences-column-key="actions"')
    end
  end

  it "keeps option builders and column metadata in the helper" do
    aggregate_failures do
      expect(helper_source).to include("def document_permission_overview_table_columns")
      expect(helper_source).to include('table_preferences_column(:document, label: "文書名"')
      expect(helper_source).to include('table_preferences_column(:download_allowed, label: "ダウンロード"')
      expect(helper_source).to include("def document_permissions_table_columns")
      expect(helper_source).to include('table_preferences_column(:actions, label: "操作"')
      expect(helper_source).to include("def document_permission_form_document_options(documents)")
      expect(helper_source).to include("def document_permission_form_company_options(companies)")
      expect(helper_source).to include("def document_permission_form_user_options(users)")
    end
  end
end
