require "rails_helper"

RSpec.describe "admin users source" do
  let(:index_source) { Rails.root.join("app/views/admin/users/index.html.slim").read }
  let(:helper_source) { Rails.root.join("app/helpers/admin/users_helper.rb").read }

  it "wires the index to rails table preferences" do
    aggregate_failures do
      expect(index_source).to include("table_key = :admin_users")
      expect(index_source).to include("admin_user_table_columns")
      expect(index_source).to include("rails_table_preference_settings(table_key: table_key)")
      expect(index_source).to include("render ColumnSettingsComponent.new")
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

  it "keeps accessible user actions and both empty states in the same view" do
    aggregate_failures do
      expect(index_source).to include("edit_admin_user_path(user, return_to: user_return_to)")
      expect(index_source).to include("button_to admin_user_path(user, return_to: user_return_to), method: :delete")
      expect(index_source).to include("aria: { label: edit_user_cue }, title: edit_user_cue")
      expect(index_source).to include("aria: { label: delete_user_cue }, title: delete_user_cue")
      expect(index_source).to include("i.bi.bi-pencil")
      expect(index_source).to include("i.bi.bi-trash")
      expect(index_source).to include("turbo_confirm:")
      expect(index_source).to include("ユーザーが未登録です")
      expect(index_source).to include("条件に一致するユーザーがいません")
      expect(index_source).to include("link_to \"条件をクリア\", admin_users_path")
      expect(helper_source).to include("pinned: true")
    end
  end

  it "uses the list-first disclosure, filter, chip, and count structure" do
    aggregate_failures do
      expect(index_source).to include("details.admin-create-panel open=(@user.errors.any?)")
      expect(index_source).to include("form.rfk_search_field :q")
      expect(index_source).to include("form.rfk_select :active")
      expect(index_source).to include("render FilterToolbarComponent.new")
      expect(index_source).to include("toolbar.with_active_filter")
      expect(index_source).to include(".admin-list-meta__count")
      expect(index_source).not_to include("user_filter_result_note")
    end
  end
end
