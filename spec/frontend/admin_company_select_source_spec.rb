require "rails_helper"

RSpec.describe "admin company selectors source" do
  let(:project_form) do
    Rails.root.join("app/views/admin/projects/_form.html.slim").read
  end

  let(:user_form) do
    Rails.root.join("app/views/admin/users/_form.html.slim").read
  end

  it "uses rails fields kit for the project company selector" do
    aggregate_failures do
      expect(project_form).to include("= form.rfk_select :company_id,")
      expect(project_form).to include("collection: @companies")
      expect(project_form).to include("collection_value_method: :id")
      expect(project_form).to include("collection_label_method: :display_name")
      expect(project_form).to include('label: "会社"')
      expect(project_form).to include("allow_clear: true")
      expect(project_form).to include('placeholder: "会社を選択（未設定可）"')
      expect(project_form).not_to include("collection_select :company_id")
    end
  end

  it "uses a remote rails fields kit combobox for the internal admin user company selector" do
    aggregate_failures do
      expect(user_form).to include("= form.rfk_combobox :company_id,")
      expect(user_form).to include("collection: []")
      expect(user_form).to include("selected: admin_user_company_selected_option(user.company)")
      expect(user_form).to include("url: company_search_admin_users_path(format: :json)")
      expect(user_form).to include("selected_url: selected_company_admin_users_path(format: :json)")
      expect(user_form).to include("value_field: \"value\"")
      expect(user_form).to include("label_field: \"text\"")
      expect(user_form).to include("search_field: \"text\"")
      expect(user_form).to include("min_length: 1")
      expect(user_form).to include("max_options: Admin::UsersController::COMPANY_SEARCH_LIMIT")
      expect(user_form).to include('label: "会社"')
      expect(user_form).to include("allow_clear: true")
      expect(user_form).to include('placeholder: "会社名・ドメインで検索（未所属可）"')
      expect(user_form).not_to include("= form.rfk_select :company_id,")
      expect(user_form).not_to include("collection: @companies")
      expect(user_form).not_to include("collection_select :company_id")
    end
  end
end
