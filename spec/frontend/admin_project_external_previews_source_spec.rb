require "rails_helper"

RSpec.describe "admin project external preview selectors source" do
  let(:view_source) do
    Rails.root.join("app/views/admin/project_external_previews/show.html.slim").read
  end

  let(:helper_source) do
    Rails.root.join("app/helpers/admin/project_external_previews_helper.rb").read
  end

  it "uses rails fields kit for the preview user and company selectors" do
    aggregate_failures do
      expect(view_source).to include("= form.rfk_select :user_id,")
      expect(view_source).to include("collection: external_preview_user_options(@preview_users)")
      expect(view_source).to include("selected: @selected_user&.id")
      expect(view_source).to include('placeholder: "外部ユーザーを検索"')
      expect(view_source).to include("= form.rfk_select :company_id,")
      expect(view_source).to include("collection: external_preview_company_options(@preview_companies)")
      expect(view_source).to include("selected: @selected_company&.id")
      expect(view_source).to include('placeholder: "会社を検索"')
      expect(view_source).not_to include("form.select :user_id")
      expect(view_source).not_to include("form.select :company_id")
    end
  end

  it "keeps searchable option labels scoped to display copy" do
    aggregate_failures do
      expect(helper_source).to include("def external_preview_user_label(user)")
      expect(helper_source).to include("user.display_name")
      expect(helper_source).to include("user.email_address")
      expect(helper_source).to include("user.company&.display_name")
      expect(helper_source).to include("def external_preview_company_label(company)")
      expect(helper_source).to include("company.display_name")
      expect(helper_source).to include("company.domain")
    end
  end
end
