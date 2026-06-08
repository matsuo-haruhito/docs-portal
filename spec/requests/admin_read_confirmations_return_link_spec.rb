require "rails_helper"

RSpec.describe "Admin read confirmations return link", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "USAGE", name: "Usage Project") }
  let(:company) { create(:company, name: "Client A", domain: "client-a.example") }
  let(:viewer) { create(:user, :external, company:, name: "Reader One", email_address: "reader@example.com") }
  let(:document) { create(:document, project:, title: "Manual", slug: "manual") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def usage_report_return_link
    parsed_html.css("a").find { _1.text.squish == "文書利用状況へ戻る" }
  end

  def usage_report_return_query
    Rack::Utils.parse_nested_query(URI.parse(usage_report_return_link["href"]).query)
  end

  it "returns to document usage reports with the selected document query context only" do
    create(:read_confirmation, document:, user: viewer, confirmed_at: Time.zone.local(2026, 5, 1, 12, 0, 0))
    sign_in_as(admin_user)

    get admin_read_confirmations_path(
      project_id: project.id,
      document_slug: document.slug,
      from: "2026-05-01",
      to: "2026-05-31",
      company_id: company.id,
      user_id: viewer.id
    )

    expect(response).to have_http_status(:ok)
    expect(usage_report_return_link).to be_present
    expect(usage_report_return_link["href"]).to start_with(admin_document_usage_reports_path)
    expect(usage_report_return_query).to include("project_id" => project.id.to_s, "q" => document.slug)
    expect(usage_report_return_query.keys & %w[from to company_id user_id document_slug]).to be_empty
  end

  it "keeps the project-only return link when no document query is selected" do
    create(:read_confirmation, document:, user: viewer, confirmed_at: Time.zone.local(2026, 5, 1, 12, 0, 0))
    sign_in_as(admin_user)

    get admin_read_confirmations_path(project_id: project.id, from: "2026-05-01", company_id: company.id)

    expect(response).to have_http_status(:ok)
    expect(usage_report_return_link).to be_present
    expect(usage_report_return_link["href"]).to eq(admin_document_usage_reports_path(project_id: project.id))
    expect(usage_report_return_query).to include("project_id" => project.id.to_s)
    expect(usage_report_return_query.keys & %w[q from company_id]).to be_empty
  end
end
