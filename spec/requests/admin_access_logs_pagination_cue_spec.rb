require "rails_helper"
require "uri"

RSpec.describe "Admin access log pagination cues", type: :request do
  let(:admin_company) { create(:company, domain: "audit-page.example.com", name: "Audit Page Company") }
  let(:admin_user) { create(:user, :internal, company: admin_company) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def pagination_link(label)
    parsed_html.css("nav.pagination a").find { |link| link.text.squish == label }
  end

  def pagination_query(label)
    link = pagination_link(label)
    return {} unless link

    Rack::Utils.parse_nested_query(URI.parse(link["href"]).query)
  end

  def create_access_log!(project:, document:, document_version:, target_name:, accessed_at:)
    AccessLog.create!(
      user: admin_user,
      company: admin_company,
      project:,
      document:,
      document_version:,
      action_type: :view,
      target_type: "page",
      target_name:,
      ip_address: "127.0.0.1",
      user_agent: "RSpec",
      accessed_at:
    )
  end

  it "labels previous and next pagination links with target pages and retained filter context" do
    pagination_project = create(:project, code: "PAGE", name: "Pagination Project")
    pagination_document = create(:document, project: pagination_project, title: "Pagination Evidence", slug: "pagination-evidence")
    pagination_version = create(:document_version, document: pagination_document, version_label: "v1.0.1")
    base_time = Time.zone.parse("2026-05-01 00:00:00 UTC")

    401.times do |index|
      create_access_log!(
        project: pagination_project,
        document: pagination_document,
        document_version: pagination_version,
        target_name: "filtered-entry-#{index}",
        accessed_at: base_time + index.minutes
      )
    end

    sign_in_as(admin_user)

    get admin_access_logs_path(
      page: 2,
      project_id: pagination_project.id,
      document_q: "Pagination Evidence",
      from: "2026-05-01",
      to: "2026-05-02"
    )

    expect(response).to have_http_status(:ok)

    previous_link = pagination_link("前の200件")
    next_link = pagination_link("次の200件")

    expect(previous_link).to be_present
    expect(next_link).to be_present
    expect(previous_link["aria-label"]).to eq("監査ログ一覧の1ページ目へ（現在の検索条件を保持）")
    expect(previous_link["title"]).to eq("監査ログ一覧の1ページ目へ（現在の検索条件を保持）")
    expect(next_link["aria-label"]).to eq("監査ログ一覧の3ページ目へ（現在の検索条件を保持）")
    expect(next_link["title"]).to eq("監査ログ一覧の3ページ目へ（現在の検索条件を保持）")
    expect(previous_link.text.squish).to eq("前の200件")
    expect(next_link.text.squish).to eq("次の200件")

    common_filter_params = {
      "project_id" => pagination_project.id.to_s,
      "document_q" => "Pagination Evidence",
      "from" => "2026-05-01",
      "to" => "2026-05-02"
    }
    expect(pagination_query("前の200件")).to include(common_filter_params.merge("page" => "1"))
    expect(pagination_query("次の200件")).to include(common_filter_params.merge("page" => "3"))
  end
end
