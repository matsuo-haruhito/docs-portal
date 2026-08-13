require "rails_helper"

RSpec.describe "Admin document permissions CSV export link", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def csv_export_link
    parsed_html.css('a[href*=".csv"]').find do |link|
      URI.parse(link["href"]).path == admin_document_permissions_path(format: :csv)
    end
  end

  it "exports without pagination parameters when no filters are active" do
    sign_in_as(admin_user)

    get admin_document_permissions_path(page: 2)

    expect(response).to have_http_status(:ok)
    expect(csv_export_link).to be_present
    expect(csv_export_link["href"]).to eq(admin_document_permissions_path(format: :csv))
  end

  it "keeps active filters in the CSV export URL" do
    sign_in_as(admin_user)

    get admin_document_permissions_path(q: "manual", access_level: "view", view: "overview", page: 2)

    expect(response).to have_http_status(:ok)
    expect(csv_export_link).to be_present
    expect(csv_export_link["href"]).to eq(
      admin_document_permissions_path(q: "manual", access_level: "view", format: :csv)
    )
  end
end
