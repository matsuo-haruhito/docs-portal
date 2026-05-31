require "rails_helper"

RSpec.describe "Admin company master visibility", type: :request do
  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def company_row(company)
    parsed_html.css("tbody tr").find { |row| row.text.include?(company.domain) }
  end

  let!(:company) { create(:company, domain: "alpha.example.com", name: "Alpha") }
  let!(:other_company) { create(:company, domain: "omega.example.com", name: "Omega") }

  it "keeps new and delete company actions visible for internal admins" do
    sign_in_as(create(:user, :internal))

    get admin_companies_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("新規登録")
    expect(parsed_html.at_css("form[action='#{admin_companies_path}']")).to be_present
    expect(company_row(company).text).to include("削除")
    expect(company_row(other_company).text).to include("削除")
  end

  it "shows company_master_admin users only same-company update affordances" do
    manager = create(:user, :external, :company_master_admin, company:)
    sign_in_as(manager)

    get admin_companies_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("自社会社情報の更新")
    expect(page_text).not_to include("新規登録")
    expect(page_text).to include("Alpha")
    expect(page_text).not_to include("Omega")

    row = company_row(company)
    expect(row.text).to include("編集")
    expect(row.text).not_to include("削除")
    expect(parsed_html.at_css("form[action='#{admin_company_path(company.public_id)}']")).to be_present
    expect(parsed_html.at_css("form[action='#{admin_companies_path}']")).to be_nil
  end
end
