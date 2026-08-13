require "rails_helper"

RSpec.describe "Admin document permission empty state clear links", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  it "clears filters inside the active assignments view" do
    document = create(:document, title: "Existing Permission Guide")
    create(:document_permission, document:, company: create(:company, name: "Existing Company"))
    sign_in_as(admin_user)

    get admin_document_permissions_path(q: "missing", view: "assignments")

    expect(response).to have_http_status(:ok)
    panel = parsed_html.at_css("#document-permissions-assignments-panel")
    expect(panel).to be_present
    expect(parsed_html.at_css("#document-permissions-overview-panel")).to be_nil
    expect(panel.css("a[href]").map { _1["href"] }).to include(admin_document_permissions_path)
  end

  it "clears filters without leaving the overview view" do
    document = create(:document, title: "Existing Permission Guide")
    create(:document_permission, document:, company: create(:company, name: "Existing Company"))
    sign_in_as(admin_user)

    get admin_document_permissions_path(q: "missing", view: "overview")

    expect(response).to have_http_status(:ok)
    panel = parsed_html.at_css("#document-permissions-overview-panel")
    expect(panel).to be_present
    expect(parsed_html.at_css("#document-permissions-assignments-panel")).to be_nil
    expect(panel.css("a[href]").map { _1["href"] }).to include(
      admin_document_permissions_path(view: "overview")
    )
  end
end
