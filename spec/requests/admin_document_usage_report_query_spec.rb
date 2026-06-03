require "rails_helper"
require "csv"

RSpec.describe "Admin document usage report query", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "QUSAGE", name: "Query Usage Project") }
  let(:company) { create(:company) }
  let(:viewer) { create(:user, :external, company:) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def row_titles
    parsed_html.css("tbody td[data-rails-table-preferences-column-key='title']").map do |cell|
      cell.css("a").first.text.squish
    end
  end

  def csv_rows
    CSV.parse(response.body, headers: true)
  end

  it "filters selected project rows by document title and slug fragments" do
    title_hit = create(:document, project:, title: "Operations Manual", slug: "operations-manual")
    slug_hit = create(:document, project:, title: "Security Policy", slug: "security-policy")
    create(:document, project:, title: "Release Notes", slug: "release-notes")
    create(:document, project: create(:project), title: "Operations Manual", slug: "other-operations")

    sign_in_as(admin_user)

    get admin_document_usage_reports_path(project_id: project.id, q: "operations")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("文書検索: operations")
    expect(row_titles).to eq([title_hit.title])

    get admin_document_usage_reports_path(project_id: project.id, q: "SECURITY-POL")

    expect(response).to have_http_status(:ok)
    expect(row_titles).to eq([slug_hit.title])
  end

  it "combines q with usage filter, date range, and sort order" do
    matched = create(:document, project:, title: "Alpha Guide", slug: "alpha-guide")
    unused_match = create(:document, project:, title: "Alpha Checklist", slug: "alpha-checklist")
    outside_period = create(:document, project:, title: "Alpha Archive", slug: "alpha-archive")
    other_query = create(:document, project:, title: "Beta Guide", slug: "beta-guide")

    create(:access_log, project:, document: matched, user: viewer, company:, action_type: :view, accessed_at: Time.zone.local(2026, 5, 2, 10, 0, 0))
    create(:access_log, project:, document: outside_period, user: viewer, company:, action_type: :view, accessed_at: Time.zone.local(2026, 4, 30, 10, 0, 0))
    create(:access_log, project:, document: other_query, user: viewer, company:, action_type: :view, accessed_at: Time.zone.local(2026, 5, 2, 11, 0, 0))

    sign_in_as(admin_user)

    get admin_document_usage_reports_path(
      project_id: project.id,
      q: "alpha",
      usage_filter: "used",
      sort_order: "last_accessed_desc",
      from: "2026-05-01",
      to: "2026-05-03"
    )

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("期間: 2026-05-01 から 2026-05-03 まで")
    expect(page_text).to include("表示中: 1件")
    expect(page_text).to match(/利用状況:\s*利用あり/)
    expect(page_text).to match(/並び順:\s*最終アクセスが新しい順/)
    expect(page_text).to include("文書検索: alpha")
    expect(row_titles).to eq([matched.title])
    expect(row_titles).not_to include(unused_match.title, outside_period.title, other_query.title)
  end

  it "applies q to CSV output with the same rows as the HTML report" do
    create(:document, project:, title: "Alpha Guide", slug: "alpha-guide")
    beta = create(:document, project:, title: "Beta Policy", slug: "beta-policy")

    sign_in_as(admin_user)

    get admin_document_usage_reports_path(project_id: project.id, q: "beta", format: :csv)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/csv")
    expect(csv_rows.headers).to eq(Admin::DocumentUsageReportsController::CSV_HEADERS)
    expect(csv_rows.size).to eq(1)
    expect(csv_rows.first.to_h).to include("文書名" => beta.title, "slug" => beta.slug)
  end

  it "shows the current query in the empty state when q leaves no rows" do
    create(:document, project:, title: "Checklist", slug: "checklist")

    sign_in_as(admin_user)

    get admin_document_usage_reports_path(project_id: project.id, q: "missing")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示中: 0件")
    expect(page_text).to include("条件に一致する文書はありません")
    expect(page_text).to include("文書検索「 missing 」に一致する文書名またはslugはありません。")
    expect(parsed_html.css("table tbody tr")).to be_empty
  end

  it "keeps q from turning the unselected project prompt into a cross-project search" do
    create(:document, project:, title: "Operations Manual", slug: "operations-manual")

    sign_in_as(admin_user)

    get admin_document_usage_reports_path(q: "operations")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("案件を選択すると集計結果を表示します。")
    expect(page_text).not_to include("集計サマリ")
    expect(parsed_html.css("table tbody tr")).to be_empty
    expect(parsed_html.at_css("input[name='q']")["value"]).to eq("operations")
  end
end
