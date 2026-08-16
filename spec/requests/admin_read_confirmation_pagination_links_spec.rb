require "rails_helper"

RSpec.describe "Admin read confirmation pagination links", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "USAGE", name: "Usage Project") }
  let(:company) { create(:company, name: "Client A", domain: "client-a.example") }
  let(:viewer) { create(:user, :external, company:, name: "Reader One", email_address: "reader@example.com") }
  let(:document) { create(:document, project:, title: "Manual", slug: "manual") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def pagination_link(direction)
    parsed_html.css("a.list-footer__page-link").find { _1["aria-label"]&.include?(direction) }
  end

  it "keeps read confirmation context and current filters in shared footer pagination cues" do
    base_time = Time.zone.local(2026, 5, 1, 9, 0, 0)
    document

    201.times do |index|
      paged_document = create(:document, project:, title: "Manual Page #{index}", slug: "manual-page-#{index}")
      create(:read_confirmation, document: paged_document, user: viewer, confirmed_at: base_time + index.minutes)
    end

    sign_in_as(admin_user)

    get admin_read_confirmations_path(
      project_id: project.id,
      document_slug: "manual-page",
      company_id: company.id,
      user_id: viewer.id,
      from: "2026-05-01",
      to: "2026-05-01"
    )

    next_link = pagination_link("進む")

    expect(response).to have_http_status(:ok)
    expect(pagination_link("戻る")).to be_nil
    expect(next_link).to be_present
    expect(next_link["title"]).to eq("既読確認内訳の2ページ目へ進む（2ページ中）")
    expect(next_link["aria-label"]).to eq("既読確認内訳の2ページ目へ進む（2ページ中）")
    expect(next_link["href"]).to include("project_id=#{project.id}")
    expect(next_link["href"]).to include("document_slug=manual-page")
    expect(next_link["href"]).to include("company_id=#{company.id}")
    expect(next_link["href"]).to include("user_id=#{viewer.id}")
    expect(next_link["href"]).to include("from=2026-05-01")
    expect(next_link["href"]).to include("to=2026-05-01")
    expect(next_link["href"]).to include("page=2")

    get admin_read_confirmations_path(
      project_id: project.id,
      document_slug: "manual-page",
      company_id: company.id,
      user_id: viewer.id,
      from: "2026-05-01",
      to: "2026-05-01",
      page: 2
    )

    previous_link = pagination_link("戻る")

    expect(response).to have_http_status(:ok)
    expect(previous_link).to be_present
    expect(previous_link["title"]).to eq("既読確認内訳の1ページ目へ戻る（2ページ中）")
    expect(previous_link["aria-label"]).to eq("既読確認内訳の1ページ目へ戻る（2ページ中）")
    expect(previous_link["href"]).to include("project_id=#{project.id}")
    expect(previous_link["href"]).to include("document_slug=manual-page")
    expect(previous_link["href"]).to include("company_id=#{company.id}")
    expect(previous_link["href"]).to include("user_id=#{viewer.id}")
    expect(previous_link["href"]).to include("from=2026-05-01")
    expect(previous_link["href"]).to include("to=2026-05-01")
    expect(previous_link["href"]).to include("page=1")
    expect(pagination_link("進む")).to be_nil
  end
end
