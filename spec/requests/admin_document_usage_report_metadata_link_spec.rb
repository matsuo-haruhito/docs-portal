require "rails_helper"

RSpec.describe "Admin document usage report metadata link", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "USAGE", name: "Usage Project") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def csv_export_link
    parsed_html.css("a").find { |link| link.text.squish == "CSV出力" }
  end

  def metadata_link
    parsed_html.css("a").find { |link| link.text.squish == "CSV条件をJSONで確認" }
  end

  it "shows a purpose-oriented JSON metadata cue with the same normalized report filters" do
    normalized_query = "alpha" * 20
    oversized_query = "#{normalized_query}should-not-leak"
    create(:document, project:, title: "#{normalized_query} Guide", slug: "normalized-guide")

    sign_in_as(admin_user)

    get admin_document_usage_reports_path(
      project_id: project.id,
      q: oversized_query,
      usage_filter: "unused",
      sort_order: "last_accessed_desc",
      from: "not-a-date",
      to: "2026-05-02"
    )

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("集計サマリ", "CSV出力")

    csv_link = csv_export_link
    expect(csv_link).to be_present
    expect(csv_link["href"]).to include("format=csv")

    link = metadata_link
    expect(link).to be_present
    expect(link["title"]).to eq("CSVと同じ条件・行数・集計サマリをJSONで確認")
    expect(link["aria-label"]).to eq("CSVと同じ条件・行数・集計サマリをJSONで確認")

    href = link["href"]
    expect(href).to include("format=json")
    expect(href).to include("project_id=#{project.id}")
    expect(href).to include("q=#{normalized_query}")
    expect(href).to include("usage_filter=unused")
    expect(href).to include("sort_order=last_accessed_desc")
    expect(href).to include("to=2026-05-02")
    expect(href).not_to include("format=csv")
    expect(href).not_to include("should-not-leak")
    expect(href).not_to include("from=not-a-date")
  end
end
