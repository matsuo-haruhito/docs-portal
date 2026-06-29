require "rails_helper"

RSpec.describe "admin document permissions source" do
  let(:form_source) { Rails.root.join("app/views/admin/document_permissions/_form.html.slim").read }
  let(:index_source) { Rails.root.join("app/views/admin/document_permissions/index.html.slim").read }
  let(:helper_source) { Rails.root.join("app/helpers/admin/document_permissions_helper.rb").read }

  it "uses remote rails fields kit comboboxes for document, company, and user fields" do
    aggregate_failures do
      expect(form_source).to include("= form.rfk_combobox :document_id,")
      expect(form_source).to include("selected: document_permission_form_document_selected_option(document_permission.document)")
      expect(form_source).to include("url: document_search_admin_document_permissions_path(format: :json)")
      expect(form_source).to include("selected_url: selected_document_admin_document_permissions_path(format: :json)")
      expect(form_source).to include('placeholder: "文書名・URL識別子・案件名で検索"')

      expect(form_source).to include("= form.rfk_combobox :company_id,")
      expect(form_source).to include("selected: document_permission_form_company_selected_option(document_permission.company)")
      expect(form_source).to include("url: company_search_admin_document_permissions_path(format: :json)")
      expect(form_source).to include("selected_url: selected_company_admin_document_permissions_path(format: :json)")
      expect(form_source).to include("max_options: Admin::DocumentPermissionsController::COMPANY_SEARCH_LIMIT")
      expect(form_source).to include('placeholder: "会社向けに付与する場合に選択"')

      expect(form_source).to include("= form.rfk_combobox :user_id,")
      expect(form_source).to include("selected: document_permission_form_user_selected_option(document_permission.user)")
      expect(form_source).to include("url: user_search_admin_document_permissions_path(format: :json)")
      expect(form_source).to include("selected_url: selected_user_admin_document_permissions_path(format: :json)")
      expect(form_source).to include("max_options: Admin::DocumentPermissionsController::USER_SEARCH_LIMIT")
      expect(form_source).to include('placeholder: "ユーザー向けに付与する場合に選択"')
      expect(form_source).to include("allow_clear: true")

      expect(form_source).not_to include("= form.rfk_select :company_id,")
      expect(form_source).not_to include("document_permission_form_company_options(@companies)")
      expect(form_source).not_to include("= form.rfk_select :user_id,")
      expect(form_source).not_to include("document_permission_form_user_options(@users)")
      expect(form_source).not_to include("form.collection_select :document_id")
      expect(form_source).not_to include("form.collection_select :company_id")
      expect(form_source).not_to include("form.collection_select :user_id")
      expect(form_source).not_to include("document_permission_form_document_options(@documents)")
    end
  end

  it "keeps access level guidance near the permission selector" do
    aggregate_failures do
      expect(form_source).to include("= form.rfk_select :access_level")
      expect(form_source).to include('label: "権限"')
      expect(form_source).to include("閲覧はportal上で文書を確認する権限です。")
      expect(form_source).to include("ダウンロードは閲覧に加えて添付・ファイル取得を許可するため、必要な場合だけ選択してください。")
      expect(form_source).to include('p.muted style="margin-top: 0.35rem;" 閲覧はportal上で文書を確認する権限です。')
    end
  end

  it "keeps target guidance separate from access level guidance" do
    aggregate_failures do
      expect(form_source).to include("会社全体に付与するか、特定ユーザー1名に付与するかを選びます。会社とユーザーはどちらか一方だけを指定してください。")
      expect(form_source).to include("保存時は、選んだ側だけを残し、もう一方は空にします。")
      expect(form_source).to include("会社またはユーザーのどちらか一方だけを残してください。")
      expect(form_source).to include("会社全体に同じ権限を付与する場合だけ選択します。ユーザー個別へ付与する場合、この欄は空にします。")
      expect(form_source).to include("特定の1名にだけ権限を付与する場合だけ選択します。会社全体へ付与する場合、この欄は空にします。")
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
      expect(helper_source).to include("def document_permission_form_document_selected_option(document)")
      expect(helper_source).to include("def document_permission_form_company_options(companies)")
      expect(helper_source).to include("def document_permission_form_company_selected_option(company)")
      expect(helper_source).to include("def document_permission_form_user_options(users)")
      expect(helper_source).to include("def document_permission_form_user_selected_option(user)")
    end
  end
end
