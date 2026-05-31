require "rails_helper"

RSpec.describe "admin project external preview selectors source" do
  let(:view_source) do
    Rails.root.join("app/views/admin/project_external_previews/show.html.slim").read
  end

  let(:helper_source) do
    Rails.root.join("app/helpers/admin/project_external_previews_helper.rb").read
  end

  it "uses rails fields kit for the preview user selector" do
    aggregate_failures do
      expect(view_source).to include("= form.rfk_select :user_id,")
      expect(view_source).to include("collection: external_preview_user_options(@preview_users)")
      expect(view_source).to include("selected: @selected_user&.id")
      expect(view_source).to include('placeholder: "外部ユーザーを検索"')
      expect(view_source).not_to include("form.select :user_id")
    end
  end

  it "keeps the company selector on the existing basic select path" do
    aggregate_failures do
      expect(view_source).to include("form.select :company_id")
      expect(view_source).to include("options_from_collection_for_select(@preview_companies, :id, :display_name, @selected_company&.id)")
      expect(view_source).not_to include("= form.rfk_select :company_id,")
    end
  end

  it "keeps searchable user option labels scoped to existing admin-visible fields" do
    aggregate_failures do
      expect(helper_source).to include("def external_preview_user_label(user)")
      expect(helper_source).to include("user.display_name")
      expect(helper_source).to include("user.email_address")
      expect(helper_source).to include("user.company&.display_name")
      expect(helper_source).not_to include("def external_preview_company_label(company)")
    end
  end
end
