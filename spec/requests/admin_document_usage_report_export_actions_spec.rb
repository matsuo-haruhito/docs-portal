require "rails_helper"
require "uri"

RSpec.describe "Admin document usage report export actions", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "USAGE", name: "Usage Project") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def link_named(label)
    parsed_html.css("a").find { |link| link.text.squish == label }
  end

  def query_params_for(link)
    Rack::Utils.parse_nested_query(URI.parse(link["href"]).query)
  end

  it "separates investigation links from CSV and JSON metadata export links" do
    create(:document, project:, title: "Report Alpha", slug: "report-alpha")
    sign_in_as(admin_user)

    get admin_document_usage_reports_path(
      project_id: project.id,
      q: " report ",
      usage_filter: "all",
      sort_order: "title",
      from: "2026-05-01",
      to: "2026-05-31"
    )

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("調査導線:")
    expect(page_text).to include("出力:")
    expect(page_text).to include("CSV本体")
    expect(page_text).to include("棚卸し用ファイル。表示中の条件で文書利用一覧を出力します。")
    expect(page_text).to include("条件確認用 metadata")
    expect(page_text).to include("CSV本体ではなく、同じ条件・行数・集計サマリを確認する補助情報です。")
    expect(page_text).to include("表示設定は一覧の列だけを変え、CSV / JSON metadata の対象条件は変えません。")

    audit_log_params = query_params_for(link_named("案件の監査ログへ"))
    expect(audit_log_params).to include(
      "project_id" => project.id.to_s,
      "from" => "2026-05-01",
      "to" => "2026-05-31"
    )
    expect(audit_log_params).not_to include("q", "usage_filter", "sort_order")
    expect(link_named("案件の既読確認内訳へ")["href"]).to eq(admin_read_confirmations_path(project_id: project.id))

    csv_params = query_params_for(link_named("CSV出力"))
    metadata_link = link_named("JSON metadataを確認")
    metadata_params = query_params_for(metadata_link)

    expect(csv_params).to include(
      "project_id" => project.id.to_s,
      "q" => "report",
      "usage_filter" => "all",
      "sort_order" => "title",
      "from" => "2026-05-01",
      "to" => "2026-05-31",
      "format" => "csv"
    )
    expect(metadata_params).to include(csv_params.merge("format" => "json"))
    expect(metadata_link["title"]).to eq("CSVと同じ条件・行数・集計サマリを確認するJSON metadata")
    expect(metadata_link["aria-label"]).to eq("CSVと同じ条件・行数・集計サマリを確認するJSON metadata")
  end
end
