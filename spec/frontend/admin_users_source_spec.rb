require "rails_helper"

RSpec.describe "admin users source" do
  let(:index_source) { Rails.root.join("app/views/admin/users/index.html.slim").read }
  let(:helper_source) { Rails.root.join("app/helpers/admin/users_helper.rb").read }

  it "wires the index to rails table preferences" do
    aggregate_failures do
      expect(index_source).to include("table_key = :admin_users")
      expect(index_source).to include("admin_user_table_columns")
      expect(index_source).to include("rails_table_preference_settings(table_key: table_key)")
      expect(index_source).to include("table_preferences_editor")
      expect(index_source).to include("table_preferences_table_tag")
      expect(index_source).to include('title: "ユーザー一覧の表示設定"')
    end
  end

  it "keeps stable table preference column keys on headers and cells" do
    %w[
      name
      email_address
      display_name
      user_type
      company
      status
      actions
    ].each do |column_key|
      expect(index_source.scan(%(data-rails-table-preferences-column-key="#{column_key}")).size).to be >= 2
      expect(helper_source).to include("table_preferences_column(:#{column_key}")
    end
  end

  it "keeps user actions and the empty state in the same view" do
    aggregate_failures do
      expect(index_source).to include("edit_link_to \"編集\"")
      expect(index_source).to include("delete_link_to \"削除\"")
      expect(index_source).to include("まだ表示中の範囲にユーザーは登録されていません。")
      expect(index_source).to include("検索条件に一致するユーザーはありません。")
      expect(index_source).to include("link_to \"条件をクリア\", admin_users_path")
      expect(helper_source).to include("pinned: true")
    end
  end

  it "summarizes applied filters without changing table preference wiring" do
    aggregate_failures do
      expect(index_source).to include("user_filter_summaries")
      expect(index_source).to include("user_filter_result_note")
      expect(index_source).to include("適用中:")
      expect(index_source).to include("検索結果:")
      expect(index_source).to include("列の表示設定は下の「ユーザー一覧の表示設定」で調整できます")
      expect(index_source).to include("表示できるユーザーがないため、列の表示設定は表示していません")
      expect(index_source).to include("table_preferences_editor")
      expect(index_source).to include("table_preferences_table_tag")
    end
  end
end
