require "rails_helper"
require "uri"

RSpec.describe "Admin document usage report audit log links", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:company) { create(:company) }
  let(:viewer) { create(:user, :external, company:) }
  let(:project) { create(:project, code: "USAGE", name: "Usage Project") }
  let(:document) { create(:document, project:, title: "Manual", slug: "manual") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def link_href(label, href_includes: nil)
    parsed_html.css("a").find do |link|
      href = link["href"].to_s

      link.text.squish == label && (href_includes.blank? || href.include?(href_includes))
    end&.[]("href")
  end

  def query_params_for(href)
    Rack::Utils.parse_nested_query(URI.parse(href).query)
  end

  before do
    create(:access_log, project:, document:, user: viewer, company:, action_type: :view, accessed_at: Time.zone.local(2026, 5, 2, 10, 0, 0))
    sign_in_as(admin_user)
  end

  it "carries valid period params to summary and row audit log links" do
    get admin_document_usage_reports_path(
      project_id: project.id,
      q: "manual",
      usage_filter: "used",
      sort_order: "last_accessed_desc",
      from: "2026-05-01",
      to: "2026-05-02"
    )

    expect(response).to have_http_status(:ok)

    summary_params = query_params_for(link_href("案件の監査ログへ"))
    row_params = query_params_for(link_href("監査ログへ", href_includes: "document_q=manual"))

    expect(summary_params).to include(
      "project_id" => project.id.to_s,
      "from" => "2026-05-01",
      "to" => "2026-05-02"
    )
    expect(summary_params).not_to include("q", "usage_filter", "sort_order", "document_q")

    expect(row_params).to include(
      "project_id" => project.id.to_s,
      "document_q" => document.slug,
      "from" => "2026-05-01",
      "to" => "2026-05-02"
    )
    expect(row_params).not_to include("q", "usage_filter", "sort_order")
  end

  it "does not add period params when no period is selected" do
    get admin_document_usage_reports_path(project_id: project.id)

    expect(response).to have_http_status(:ok)

    summary_params = query_params_for(link_href("案件の監査ログへ"))
    row_params = query_params_for(link_href("監査ログへ", href_includes: "document_q=manual"))

    expect(summary_params).to eq("project_id" => project.id.to_s)
    expect(row_params).to eq("project_id" => project.id.to_s, "document_q" => document.slug)
  end

  it "does not leak invalid dates or unrelated usage filters to audit log links" do
    get admin_document_usage_reports_path(
      project_id: project.id,
      q: "manual",
      usage_filter: "used",
      sort_order: "last_accessed_desc",
      from: "not-a-date",
      to: "2026-05-02"
    )

    expect(response).to have_http_status(:ok)

    summary_params = query_params_for(link_href("案件の監査ログへ"))
    row_params = query_params_for(link_href("監査ログへ", href_includes: "document_q=manual"))

    expect(summary_params).to include(
      "project_id" => project.id.to_s,
      "to" => "2026-05-02"
    )
    expect(summary_params).not_to include("from", "q", "usage_filter", "sort_order", "document_q")

    expect(row_params).to include(
      "project_id" => project.id.to_s,
      "document_q" => document.slug,
      "to" => "2026-05-02"
    )
    expect(row_params).not_to include("from", "q", "usage_filter", "sort_order")
  end
end
