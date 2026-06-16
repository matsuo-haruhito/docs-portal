require "csv"
require "rails_helper"
require "uri"

RSpec.describe "Admin read confirmations CSV pagination", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:company) { create(:company, name: "Client A", domain: "client-a.example") }
  let(:viewer) { create(:user, :external, company:, name: "CSV Page Reader", email_address: "csv-page-reader@example.com") }
  let(:project) { create(:project, code: "READCSV", name: "Read CSV Project") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def read_confirmation_rows
    parsed_html.css("table tbody tr").map { _1.text.squish }
  end

  def csv_export_link
    parsed_html.css("a").find { |link| link.text.squish == "CSV出力" }
  end

  def csv_export_query
    Rack::Utils.parse_nested_query(URI.parse(csv_export_link["href"]).query)
  end

  it "exports only the current page while preserving read confirmation filters" do
    base_time = Time.zone.local(2026, 5, 1, 9, 0, 0)

    201.times do |index|
      paged_document = create(
        :document,
        project:,
        title: "Paged Manual #{index}",
        slug: "paged-manual-#{index}"
      )
      create(:read_confirmation, document: paged_document, user: viewer, confirmed_at: base_time + index.minutes)
    end

    sign_in_as(admin_user)

    filter_params = {
      project_id: project.id,
      document_slug: "paged-manual",
      company_id: company.id,
      user_id: viewer.id,
      from: "2026-05-01",
      to: "2026-05-01",
      page: 2
    }

    get admin_read_confirmations_path(filter_params)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示範囲: 201-201件目 / 条件一致 201件 / Page 2 / 2")
    expect(page_text).to include("CSV出力にも同じ絞り込み条件と現在のページ範囲を反映します。")
    expect(read_confirmation_rows).to contain_exactly(a_string_including("Paged Manual 0", "CSV Page Reader / csv-page-reader@example.com", "Client A", "paged-manual-0"))

    expect(csv_export_query).to include(
      "project_id" => project.id.to_s,
      "document_slug" => "paged-manual",
      "company_id" => company.id.to_s,
      "user_id" => viewer.id.to_s,
      "from" => "2026-05-01",
      "to" => "2026-05-01",
      "page" => "2"
    )

    get admin_read_confirmations_path(filter_params.merge(format: :csv))

    csv = CSV.parse(response.body, headers: true)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/csv")
    expect(csv.headers).to eq(["確認日時", "文書名", "document slug", "確認者", "email", "会社"])
    expect(csv.size).to eq(1)
    expect(csv.first.to_h).to include(
      "確認日時" => "2026-05-01 09:00:00",
      "文書名" => "Paged Manual 0",
      "document slug" => "paged-manual-0",
      "確認者" => "CSV Page Reader",
      "email" => "csv-page-reader@example.com",
      "会社" => "Client A"
    )
    expect(response.body).not_to include("Paged Manual 1")
    expect(response.body).not_to include("Paged Manual 200")
  end
end
