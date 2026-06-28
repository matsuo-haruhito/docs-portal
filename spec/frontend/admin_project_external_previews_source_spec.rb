require "rails_helper"

RSpec.describe "admin project external preview selectors source" do
  let(:view_source) do
    Rails.root.join("app/views/admin/project_external_previews/show.html.slim").read
  end

  let(:helper_source) do
    Rails.root.join("app/helpers/admin/project_external_previews_helper.rb").read
  end

  it "uses remote rails fields kit combobox for the preview user selector" do
    aggregate_failures do
      expect(view_source).to include("= form.rfk_combobox :user_id,")
      expect(view_source).to include("collection: []")
      expect(view_source).to include("selected: external_preview_user_selected_option(@selected_user)")
      expect(view_source).to include("url: external_preview_user_search_admin_project_path(@project, format: :json)")
      expect(view_source).to include("selected_url: selected_external_preview_user_admin_project_path(@project, format: :json)")
      expect(view_source).to include("max_options: 20")
      expect(view_source).to include('placeholder: "外部ユーザーを検索"')
      expect(view_source).not_to include("= form.rfk_select :user_id,")
      expect(view_source).not_to include("form.select :user_id")
    end
  end

  it "uses remote rails fields kit combobox for the company selector with target cue copy" do
    aggregate_failures do
      expect(view_source).to include("= form.rfk_combobox :company_id,")
      expect(view_source).to include("selected: external_preview_company_selected_option(@selected_company)")
      expect(view_source).to include("url: external_preview_company_search_admin_project_path(@project, format: :json)")
      expect(view_source).to include("selected_url: selected_external_preview_company_admin_project_path(@project, format: :json)")
      expect(view_source).to include("会社を選ぶと、その会社に所属する有効な外部ユーザーの表示可否をまとめて確認します。")
      expect(view_source).not_to include("form.select :company_id")
      expect(view_source).not_to include("= form.rfk_select :company_id,")
    end
  end

  it "keeps remote option labels scoped to existing admin-visible fields" do
    aggregate_failures do
      expect(helper_source).to include("def external_preview_user_label(user)")
      expect(helper_source).to include("def external_preview_user_selected_option(user)")
      expect(helper_source).to include("def external_preview_company_selected_option(company)")
      expect(helper_source).to include("def external_preview_company_label(company)")
      expect(helper_source).to include("user.display_name")
      expect(helper_source).to include("user.email_address")
      expect(helper_source).to include("user.company&.display_name")
      expect(helper_source).to include("company.display_name")
      expect(helper_source).to include("company.domain")
    end
  end
end
