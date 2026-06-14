require "csv"
require "rails_helper"
require "uri"

RSpec.describe "Admin export metadata", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def metadata_link
    parsed_html.css("a[href]").find { _1.text.squish == "CSV条件metadata JSON" }
  end

  def metadata_link_href
    metadata_link["href"]
  end

  def link_query(link)
    Rack::Utils.parse_nested_query(URI.parse(link["href"]).query)
  end

  describe "access log export metadata" do
    let(:project) { create(:project, code: "META", name: "Metadata Project") }
    let(:document) { create(:document, project:, title: "Metadata Document", slug: "metadata-document") }

    it "exposes normalized current-filter metadata without changing CSV rows" do
      create(
        :access_log,
        user: admin_user,
        company: admin_user.company,
        project:,
        document:,
        action_type: :download,
        target_type: "page",
        target_name: "metadata-target",
        ip_address: "203.0.113.55",
        accessed_at: Time.zone.local(2026, 5, 10, 12, 0, 0)
      )

      sign_in_as(admin_user)

      get admin_access_logs_path(
        project_id: project.id,
        document_q: "Metadata Document",
        q: "metadata-target",
        from: "2026-05-10",
        to: "bad-date",
        page: 2
      )

      expect(response).to have_http_status(:ok)
      expect(metadata_link).to be_present
      expect(metadata_link_href).to match(/(\.json|format=json)/)
      expect(link_query(metadata_link)).to include(
        "project_id" => project.id.to_s,
        "document_q" => "Metadata Document",
        "q" => "metadata-target",
        "from" => "2026-05-10",
        "to" => "bad-date"
      )
      expect(link_query(metadata_link)).not_to include("page")

      get admin_access_logs_path(
        format: :json,
        project_id: project.id,
        document_q: "Metadata Document",
        q: "metadata-target",
        from: "2026-05-10",
        to: "bad-date",
        page: 2
      )

      metadata = JSON.parse(response.body)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/json")
      expect(metadata).to include(
        "report_type" => "access_logs",
        "row_limit" => Admin::AccessLogsController::ACCESS_LOGS_PER_PAGE,
        "export_scope" => "current_filter_latest_rows"
      )
      expect(metadata["description"]).to include("表示中ページではなく")
      expect(metadata["filters"]).to include(
        "project_id" => project.id.to_s,
        "document_q" => "Metadata Document",
        "q" => "metadata-target",
        "from" => "2026-05-10"
      )
      expect(metadata["filters"]).not_to have_key("to")
      expect(metadata["filters"].dig("project", "code")).to eq("META")
      expect(metadata["ignored_filters"]).to eq(["to"])
      expect(metadata["summary"]).to include("最新200件")

      get admin_access_logs_path(format: :csv, project_id: project.id, document_q: "Metadata Document", q: "metadata-target")

      rows = CSV.parse(response.body, headers: true)
      expect(response).to have_http_status(:ok)
      expect(rows.headers).to eq(Admin::AccessLogsController::CSV_HEADERS)
      expect(rows.first["対象名"]).to eq("metadata-target")
    end
  end

  describe "document usage export metadata" do
    let(:project) { create(:project, code: "USGMETA", name: "Usage Metadata Project") }
    let(:company) { create(:company) }
    let(:viewer) { create(:user, :external, company:) }
    let(:document) { create(:document, project:, title: "Metadata Manual", slug: "metadata-manual") }

    it "exposes selected project metadata while keeping CSV header-first" do
      create(:access_log, project:, document:, user: viewer, company:, action_type: :view, accessed_at: Time.zone.local(2026, 5, 2, 10, 0, 0))

      sign_in_as(admin_user)

      get admin_document_usage_reports_path(
        project_id: project.id,
        q: "metadata",
        usage_filter: "used",
        sort_order: "last_accessed_desc",
        from: "2026-05-01",
        to: "2026-05-03"
      )

      expect(response).to have_http_status(:ok)
      expect(metadata_link).to be_present
      expect(metadata_link_href).to match(/(\.json|format=json)/)
      expect(link_query(metadata_link)).to include(
        "project_id" => project.id.to_s,
        "q" => "metadata",
        "usage_filter" => "used",
        "sort_order" => "last_accessed_desc",
        "from" => "2026-05-01",
        "to" => "2026-05-03"
      )

      get admin_document_usage_reports_path(
        format: :json,
        project_id: project.id,
        q: "metadata",
        usage_filter: "used",
        sort_order: "last_accessed_desc",
        from: "2026-05-01",
        to: "2026-05-03"
      )

      metadata = JSON.parse(response.body)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/json")
      expect(metadata).to include(
        "report_type" => "document_usage_report",
        "export_scope" => "current_project_usage_report",
        "row_count" => 1
      )
      expect(metadata["filters"]).to include(
        "project_id" => project.id,
        "q" => "metadata",
        "usage_filter" => "used",
        "usage_filter_label" => "利用あり",
        "sort_order" => "last_accessed_desc",
        "sort_order_label" => "最終アクセスが新しい順",
        "from" => "2026-05-01",
        "to" => "2026-05-03",
        "period_label" => "2026-05-01 から 2026-05-03 まで"
      )
      expect(metadata["filters"].dig("project", "code")).to eq("USGMETA")
      expect(metadata["summary"]).to include("Usage Metadata Project")
      expect(metadata["summary"]).to include("利用あり")
      expect(metadata["summary"]).to include("metadata")

      get admin_document_usage_reports_path(format: :csv, project_id: project.id, q: "metadata", usage_filter: "used")

      rows = CSV.parse(response.body, headers: true)
      expect(response).to have_http_status(:ok)
      expect(rows.headers).to eq(Admin::DocumentUsageReportsController::CSV_HEADERS)
      expect(rows.first["slug"]).to eq("metadata-manual")
    end

    it "keeps missing project behavior aligned with CSV export" do
      sign_in_as(admin_user)

      get admin_document_usage_reports_path(format: :json)

      expect(response).to redirect_to(admin_document_usage_reports_path)
      expect(flash[:alert]).to eq("CSV出力には案件選択が必要です。")
    end
  end
end
