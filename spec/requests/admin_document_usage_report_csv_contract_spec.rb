require "rails_helper"
require "csv"

RSpec.describe "Admin document usage report CSV contract", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:company) { create(:company) }
  let(:viewer) { create(:user, :external, company:) }
  let(:project) { create(:project, code: "USAGE", name: "Usage Project") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def row_titles
    parsed_html.css("tbody td[data-rails-table-preferences-column-key='title']").map do |cell|
      cell.css("a").first.text.squish
    end
  end

  def csv_rows
    CSV.parse(response.body, headers: true)
  end

  def create_document_usage_rows
    used_old = create(:document, project:, title: "Report Alpha", slug: "report-alpha")
    used_new = create(:document, project:, title: "Report Beta", slug: "report-beta")
    read_only = create(:document, project:, title: "Report Policy", slug: "report-policy")
    unused = create(:document, project:, title: "Report Draft", slug: "report-draft")
    out_of_range = create(:document, project:, title: "Report Gamma", slug: "report-gamma")
    nonmatching = create(:document, project:, title: "Manual", slug: "manual")

    create(:access_log, project:, document: used_old, user: viewer, company:, action_type: :view, accessed_at: Time.zone.local(2026, 5, 1, 10, 0, 0))
    create(:access_log, project:, document: used_new, user: viewer, company:, action_type: :download, accessed_at: Time.zone.local(2026, 5, 2, 10, 0, 0))
    create(:read_confirmation, document: read_only, user: viewer, confirmed_at: Time.zone.local(2026, 5, 2, 12, 0, 0))
    create(:access_log, project:, document: out_of_range, user: viewer, company:, action_type: :view, accessed_at: Time.zone.local(2026, 5, 3, 10, 0, 0))
    create(:access_log, project:, document: nonmatching, user: viewer, company:, action_type: :view, accessed_at: Time.zone.local(2026, 5, 2, 11, 0, 0))

    {
      used_old:,
      used_new:,
      read_only:,
      unused:,
      out_of_range:,
      nonmatching:
    }
  end

  it "uses the same q, used filter, date range, and descending last-access order for HTML and CSV" do
    documents = create_document_usage_rows
    params = {
      project_id: project.id,
      q: "report",
      usage_filter: "used",
      sort_order: "last_accessed_desc",
      from: "2026-05-01",
      to: "2026-05-02"
    }

    sign_in_as(admin_user)

    get admin_document_usage_reports_path(params)
    expect(response).to have_http_status(:ok)
    expect(row_titles).to eq(["Report Beta", "Report Alpha", "Report Policy"])

    get admin_document_usage_reports_path(params.merge(format: :csv))
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/csv")
    expect(csv_rows.headers).to eq(Admin::DocumentUsageReportsController::CSV_HEADERS)
    expect(csv_rows.map { _1["文書名"] }).to eq(["Report Beta", "Report Alpha", "Report Policy"])
    expect(csv_rows.map { _1["slug"] }).to eq(%w[report-beta report-alpha report-policy])
    expect(csv_rows.map { _1["slug"] }).not_to include(
      documents[:unused].slug,
      documents[:out_of_range].slug,
      documents[:nonmatching].slug
    )
    expect(csv_rows.map { _1["利用"] }).to eq(["利用あり", "利用あり", "既読のみ"])
  end

  it "keeps CSV ordering aligned with ascending last-access sort" do
    create_document_usage_rows
    params = {
      project_id: project.id,
      q: "report",
      usage_filter: "used",
      sort_order: "last_accessed_asc",
      from: "2026-05-01",
      to: "2026-05-02"
    }

    sign_in_as(admin_user)

    get admin_document_usage_reports_path(params)
    expect(response).to have_http_status(:ok)
    expect(row_titles).to eq(["Report Alpha", "Report Beta", "Report Policy"])

    get admin_document_usage_reports_path(params.merge(format: :csv))
    expect(response).to have_http_status(:ok)
    expect(csv_rows.map { _1["文書名"] }).to eq(["Report Alpha", "Report Beta", "Report Policy"])
  end

  it "applies unused filtering to CSV without exporting used rows" do
    documents = create_document_usage_rows

    sign_in_as(admin_user)

    get admin_document_usage_reports_path(
      project_id: project.id,
      q: "report",
      usage_filter: "unused",
      format: :csv
    )

    expect(response).to have_http_status(:ok)
    expect(csv_rows.map { _1["slug"] }).to eq([documents[:unused].slug])
    expect(csv_rows.first["利用"]).to eq("未利用")
  end

  it "ignores invalid CSV date inputs while keeping valid date constraints" do
    create_document_usage_rows

    sign_in_as(admin_user)

    get admin_document_usage_reports_path(
      project_id: project.id,
      q: "report",
      usage_filter: "used",
      from: "not-a-date",
      to: "2026-05-01",
      format: :csv
    )

    expect(response).to have_http_status(:ok)
    expect(csv_rows.map { _1["slug"] }).to eq(%w[report-alpha])
  end

  it "does not export all rows for invalid project CSV requests" do
    create_document_usage_rows

    sign_in_as(admin_user)

    get admin_document_usage_reports_path(project_id: "999999", format: :csv)

    expect(response).to redirect_to(admin_document_usage_reports_path)
    expect(flash[:alert]).to eq("CSV出力には案件選択が必要です。")
  end
end
