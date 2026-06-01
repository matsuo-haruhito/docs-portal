require "rails_helper"

RSpec.describe "admin companies source" do
  let(:index_source) { Rails.root.join("app/views/admin/companies/index.html.slim").read }
  let(:helper_source) { Rails.root.join("app/helpers/admin/companies_helper.rb").read }

  it "wires the index to rails table preferences" do
    aggregate_failures do
      expect(index_source).to include("table_key = :admin_companies")
      expect(index_source).to include("admin_company_table_columns")
      expect(index_source).to include("rails_table_preference_settings(table_key: table_key)")
      expect(index_source).to include("table_preferences_editor")
      expect(index_source).to include("table_preferences_table_tag")
      expect(index_source).to include('title: "会社一覧の表示設定"')
    end
  end

  it "keeps stable table preference column keys on headers and cells" do
    %w[
      domain
      name
      display_name
      status
      actions
    ].each do |column_key|
      expect(index_source.scan(%(data-rails-table-preferences-column-key="#{column_key}")).size).to be >= 2
      expect(helper_source).to include("table_preferences_column(:#{column_key}")
    end
  end

  it "keeps role-specific actions and the empty state in the same view" do
    aggregate_failures do
      expect(index_source).to include("company_form_title = admin_user? ?")
      expect(index_source).to include("if admin_user?")
      expect(index_source).to include("delete_link_to")
      expect(index_source).to include("まだ会社は登録されていません。")
      expect(index_source).to include("internal admin に確認してください。")
      expect(helper_source).to include("pinned: true")
    end
  end
end
