require "rails_helper"

RSpec.describe "Document set index labels", type: :request do
  let(:user) { create(:user, :internal) }
  let(:project) { create(:project, name: "Label Project") }

  it "shows localized set type and visibility labels instead of raw enum keys" do
    create(
      :document_set,
      project:,
      name: "Delivery Set",
      set_type: :delivery,
      visibility_policy: :internal_only
    )

    sign_in_as(user)
    get project_document_sets_path(project)

    expect(response).to have_http_status(:ok)

    page_text = Nokogiri::HTML(response.body).text.squish

    aggregate_failures do
      expect(page_text).to include("Delivery Set")
      expect(page_text).to include("送付用")
      expect(page_text).to include("社内のみ")
      expect(page_text).not_to include("delivery")
      expect(page_text).not_to include("internal_only")
    end
  end
end
