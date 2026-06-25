require "rails_helper"

RSpec.describe "admin/read_confirmations/index source" do
  let(:view_source) { Rails.root.join("app/views/admin/read_confirmations/index.html.slim").read }
  let(:helper_source) { Rails.root.join("app/helpers/admin/read_confirmations_helper.rb").read }

  it "uses rails_table_preferences for the result table only" do
    expect(view_source).to include("table_key = :admin_read_confirmations")
    expect(view_source).to include("table_columns = read_confirmation_table_columns")
    expect(view_source).to include("rails_table_preference_settings(table_key: table_key)")
    expect(view_source).to include("table_preferences_editor(table_key: table_key, settings: table_settings, columns: table_columns, title: \"既読確認内訳の表示設定\")")
    expect(view_source).to include("table_preferences_table_tag(table_key: table_key, settings: table_settings, columns: table_columns)")
  end

  it "keeps stable column keys on headers and cells" do
    %w[confirmed_at document user company document_slug].each do |column_key|
      expect(view_source.scan(%(data-rails-table-preferences-column-key=\"#{column_key}\")).size).to eq(2)
    end
  end

  it "defines matching column metadata without changing filters or empty states" do
    expect(helper_source).to include("table_preferences_column(:confirmed_at, label: \"確認日時\", default_width: 170, pinned: true, sortable: true)")
    expect(helper_source).to include("table_preferences_column(:document, label: \"文書\", default_width: 220, pinned: true, overflow: :ellipsis)")
    expect(helper_source).to include("table_preferences_column(:user, label: \"確認者\", default_width: 220, overflow: :ellipsis)")
    expect(helper_source).to include("table_preferences_column(:company, label: \"会社\", default_width: 180, overflow: :ellipsis)")
    expect(helper_source).to include("table_preferences_column(:document_slug, label: \"文書URL識別子\", default_width: 170, overflow: :ellipsis)")
    expect(view_source).to include("form.rfk_combobox :project_id")
    expect(view_source).to include("read_confirmation_project_selected_option(@selected_project)")
    expect(view_source).to include("project_search_admin_read_confirmations_path(format: :json)")
    expect(view_source).to include("selected_project_admin_read_confirmations_path(format: :json)")
    expect(view_source).to include("form.search_field :document_slug")
    expect(view_source).to include("form.date_field :from")
    expect(view_source).to include("form.date_field :to")
    expect(view_source).to include("期間は既読確認日時（confirmed_at）を対象にします。文書利用状況の閲覧・ダウンロード集計期間とは別の条件です。")
    expect(view_source).to include("指定した文書URL識別子に一致する文書がないため、既読確認は表示されません。")
  end
end
