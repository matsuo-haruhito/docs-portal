require "csv"
require "rails_helper"

RSpec.describe "Admin read confirmation document query", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "USAGE", name: "Usage Project") }
  let(:other_project) { create(:project, code: "OTHER", name: "Other Project") }
  let(:company) { create(:company, name: "Client A", domain: "client-a.example") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def read_confirmation_rows
    parsed_html.css("table tbody tr").map { _1.text.squish }
  end

  it "filters read confirmations by document title fragment within the selected project" do
    safety_manual = create(:document, project:, title: "Safety Manual", slug: "safety-manual")
    safety_appendix = create(:document, project:, title: "Safety Appendix", slug: "appendix")
    policy = create(:document, project:, title: "Policy", slug: "policy")
    outside_safety = create(:document, project: other_project, title: "Safety Manual", slug: "safety-manual")
    create(:read_confirmation, document: safety_manual, user: create(:user, :external, name: "Safety Reader", email_address: "safety-reader@example.com"), confirmed_at: Time.zone.local(2026, 5, 1, 12, 0, 0))
    create(:read_confirmation, document: safety_appendix, user: create(:user, :external, name: "Appendix Reader", email_address: "appendix-reader@example.com"), confirmed_at: Time.zone.local(2026, 5, 2, 12, 0, 0))
    create(:read_confirmation, document: policy, user: create(:user, :external, name: "Policy Reader", email_address: "policy-reader@example.com"), confirmed_at: Time.zone.local(2026, 5, 3, 12, 0, 0))
    create(:read_confirmation, document: outside_safety, user: create(:user, :external, name: "Outside Reader", email_address: "outside-reader@example.com"), confirmed_at: Time.zone.local(2026, 5, 4, 12, 0, 0))

    sign_in_as(admin_user)

    get admin_read_confirmations_path(project_id: project.id, document_slug: "Safety")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("文書名またはURL識別子")
    expect(page_text).to include("文書URL識別子: Safety / 一致文書: 2件")
    expect(page_text).to include("表示中: 2件")
    expect(read_confirmation_rows.join).to include("Safety Manual")
    expect(read_confirmation_rows.join).to include("Safety Appendix")
    expect(read_confirmation_rows.join).not_to include("Policy")
    expect(read_confirmation_rows.join).not_to include("Outside Reader")
  end

  it "applies the same slug fragment, company, user, and date filters to CSV export" do
    matching_reader = create(:user, :external, company:, name: "CSV Reader", email_address: "csv-reader@example.com")
    same_company_reader = create(:user, :external, company:, name: "Same Company Reader", email_address: "same-company-reader@example.com")
    other_company = create(:company, name: "Client B", domain: "client-b.example")
    other_company_reader = create(:user, :external, company: other_company, name: "Other Company Reader", email_address: "other-company-reader@example.com")
    matching_document = create(:document, project:, title: "Manual", slug: "manual-v1")
    other_document = create(:document, project:, title: "Policy", slug: "policy")
    outside_document = create(:document, project: other_project, title: "Outside Manual", slug: "manual-v1")
    outside_reader = create(:user, :external, name: "Outside CSV Reader", email_address: "outside-csv-reader@example.com")

    create(:read_confirmation, document: matching_document, user: matching_reader, confirmed_at: Time.zone.local(2026, 5, 2, 12, 0, 0))
    create(:read_confirmation, document: matching_document, user: same_company_reader, confirmed_at: Time.zone.local(2026, 5, 2, 13, 0, 0))
    create(:read_confirmation, document: matching_document, user: other_company_reader, confirmed_at: Time.zone.local(2026, 5, 2, 14, 0, 0))
    create(:read_confirmation, document: other_document, user: matching_reader, confirmed_at: Time.zone.local(2026, 5, 2, 15, 0, 0))
    create(:read_confirmation, document: outside_document, user: outside_reader, confirmed_at: Time.zone.local(2026, 5, 2, 16, 0, 0))

    sign_in_as(admin_user)

    get admin_read_confirmations_path(
      format: :csv,
      project_id: project.id,
      document_slug: "manual-v1",
      company_id: company.id,
      user_id: matching_reader.id,
      from: "2026-05-01",
      to: "2026-05-03"
    )

    csv = CSV.parse(response.body, headers: true)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/csv")
    expect(csv.size).to eq(1)
    expect(csv.first.to_h).to include(
      "文書名" => "Manual",
      "document slug" => "manual-v1",
      "確認者" => "CSV Reader",
      "email" => "csv-reader@example.com",
      "会社" => "Client A"
    )
    expect(response.body).not_to include("Same Company Reader")
    expect(response.body).not_to include("Other Company Reader")
    expect(response.body).not_to include("Policy")
    expect(response.body).not_to include("Outside Manual")
  end
end
