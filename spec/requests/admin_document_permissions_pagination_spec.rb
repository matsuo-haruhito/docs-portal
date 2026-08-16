require "rails_helper"

RSpec.describe "Admin document permissions pagination", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  before do
    26.times do |index|
      document = create(
        :document,
        title: format("権限ページ確認文書 %02d", index),
        slug: format("permission-page-%02d", index)
      )
      create(:document_permission, document:, company: create(:company, name: format("権限確認会社 %02d", index)))
    end
    sign_in_as(admin_user)
  end

  it "reaches the second assignments page and keeps the active view" do
    get admin_document_permissions_path(view: "assignments", page: 2)

    expect(response).to have_http_status(:ok)
    expect(parsed_html.css("#document-permissions-assignments-panel tbody tr").size).to eq(1)
    expect(parsed_html.at_css("#document-permissions-assignments-panel").text).to include("権限ページ確認文書 25")
    expect(parsed_html.at_css("#document-permissions-overview-panel")).to be_nil

    previous_link = parsed_html.at_css('.list-footer__pagination a[href*="page=1"]')
    expect(previous_link).to be_present
    expect(Rack::Utils.parse_query(URI.parse(previous_link["href"]).query)).to include(
      "view" => "assignments",
      "page" => "1"
    )
  end

  it "paginates the overview independently from assignment rows" do
    get admin_document_permissions_path(view: "overview", page: 2)

    expect(response).to have_http_status(:ok)
    expect(parsed_html.css("#document-permissions-overview-panel tbody tr").size).to eq(1)
    expect(parsed_html.at_css("#document-permissions-overview-panel").text).to include("権限ページ確認文書 25")
    expect(parsed_html.at_css("#document-permissions-assignments-panel")).to be_nil
  end
end
