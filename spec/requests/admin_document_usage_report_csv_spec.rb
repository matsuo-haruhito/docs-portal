require "csv"
require "rails_helper"

RSpec.describe "Admin document usage report CSV", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:external_user) { create(:user, :external) }
  let(:project) { create(:project, code: "USAGE", name: "Usage Project") }
  let(:company) { create(:company) }
  let(:viewer) { create(:user, :external, company:) }
  let(:document) { create(:document, project:, title: "Manual", slug: "manual") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def parsed_csv
    CSV.parse(response.body, headers: true)
  end

  it "shows a CSV export link only after a project is selected" do
    sign_in_as(admin_user)

    get admin_document_usage_reports_path

    expect(response).to have_http_status(:ok)
    expect(parsed_html.css("a").map { _1.text.squish }).not_to include("CSV出力")

    get admin_document_usage_reports_path(
      project_id: project.id,
      usage_filter: "used",
      sort_order: "last_accessed_desc",
      from: "2026-05-01",
      to: "2026-05-02"
    )

    export_link = parsed_html.css("a").find { _1.text.squish == "CSV出力" }
    expect(export_link).to be_present
    expect(export_link["href"]).to include("/admin/document_usage_reports")
    expect(export_link["href"]).to include("format=csv")
    expect(export_link["href"]).to include("project_id=#{project.id}")
    expect(export_link["href"]).to include("usage_filter=used")
    expect(export_link["href"]).to include("sort_order=last_accessed_desc")
    expect(export_link["href"]).to include("from=2026-05-01")
    expect(export_link["href"]).to include("to=2026-05-02")
  end

  it "exports the selected project report with the same usage and period filters as HTML" do
    newest_document = create(:document, project:, title: "Guide", slug: "guide")
    read_only_document = create(:document, project:, title: "Policy", slug: "policy")
    outside_document = create(:document, project:, title: "Checklist", slug: "checklist")

    create(:access_log, project:, document:, user: viewer, company:, action_type: :download, accessed_at: Time.zone.local(2026, 5, 1, 10, 0, 0))
    create(:access_log, project:, document: newest_document, user: viewer, company:, action_type: :view, accessed_at: Time.zone.local(2026, 5, 2, 10, 0, 0))
    create(:read_confirmation, document: read_only_document, user: viewer, confirmed_at: Time.zone.local(2026, 5, 2, 12, 0, 0))
    create(:access_log, project:, document: outside_document, user: viewer, company:, action_type: :view, accessed_at: Time.zone.local(2026, 5, 3, 10, 0, 0))

    sign_in_as(admin_user)

    get admin_document_usage_reports_path(
      format: :csv,
      project_id: project.id,
      usage_filter: "used",
      sort_order: "last_accessed_desc",
      from: "2026-05-01",
      to: "2026-05-02"
    )

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/csv")
    expect(response.headers["Content-Disposition"]).to include("document-usage-report-USAGE-")

    csv = parsed_csv
    expect(csv.headers).to eq(%w[文書名 slug カテゴリ 種別 公開範囲 利用 閲覧 ダウンロード 既読確認 最終アクセス])
    expect(csv.map { _1["文書名"] }).to eq(%w[Guide Manual Policy])
    expect(csv.map { _1["文書名"] }).not_to include("Checklist")

    guide_row = csv.find { _1["slug"] == "guide" }
    manual_row = csv.find { _1["slug"] == "manual" }
    policy_row = csv.find { _1["slug"] == "policy" }

    expect(guide_row["利用"]).to eq("利用あり")
    expect(guide_row["閲覧"]).to eq("1")
    expect(guide_row["ダウンロード"]).to eq("0")
    expect(manual_row["閲覧"]).to eq("0")
    expect(manual_row["ダウンロード"]).to eq("1")
    expect(policy_row["利用"]).to eq("既読のみ")
    expect(policy_row["既読確認"]).to eq("1")
  end

  it "does not export every project when project_id is missing or invalid" do
    create(:document, project:, title: "Manual", slug: "manual")

    sign_in_as(admin_user)

    get admin_document_usage_reports_path(format: :csv)
    expect(response).to redirect_to(admin_document_usage_reports_path)
    expect(flash[:alert]).to eq("CSV出力には案件選択が必要です。")

    get admin_document_usage_reports_path(format: :csv, project_id: "999999")
    expect(response).to redirect_to(admin_document_usage_reports_path)
    expect(flash[:alert]).to eq("CSV出力には案件選択が必要です。")
  end

  it "ignores table preference params when selecting CSV columns and report rows" do
    hidden_document = create(:document, project:, title: "Checklist", slug: "checklist")
    create(:access_log, project:, document:, user: viewer, company:, action_type: :view, accessed_at: Time.zone.local(2026, 5, 1, 10, 0, 0))

    sign_in_as(admin_user)

    get admin_document_usage_reports_path(
      format: :csv,
      project_id: project.id,
      usage_filter: "used",
      table_preferences: {
        admin_document_usage_reports: {
          hidden_columns: %w[slug view_count download_count read_confirmation_count]
        }
      }
    )

    csv = parsed_csv
    expect(csv.headers).to include("slug", "閲覧", "ダウンロード", "既読確認")
    expect(csv.map { _1["slug"] }).to eq([document.slug])
    expect(csv.map { _1["slug"] }).not_to include(hidden_document.slug)
  end

  it "forbids external users" do
    sign_in_as(external_user)

    get admin_document_usage_reports_path(format: :csv, project_id: project.id)

    expect(response).to have_http_status(:forbidden)
  end
end
