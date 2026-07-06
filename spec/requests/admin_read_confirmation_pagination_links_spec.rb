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

  def pagination_link(text)
    parsed_html.css("a.button.secondary").find { _1.text.squish == text }
  end

  def disabled_pagination_control(text)
    parsed_html.css("span.button.secondary[aria-disabled='true']").find { _1.text.squish == text }
  end

  it "keeps visible pagination text while adding read confirmation context to link cues" do
    base_time = Time.zone.local(2026, 5, 1, 9, 0, 0)
    document

    201.times do |index|
      paged_document = create(:document, project:, title: "Manual Page #{index}", slug: "manual-page-#{index}")
      create(:read_confirmation, document: paged_document, user: viewer, confirmed_at: base_time + index.minutes)
    end

    sign_in_as(admin_user)

    get admin_read_confirmations_path(
      project_id: project.id,
      document_slug: document.slug,
      company_id: company.id,
      user_id: viewer.id,
      from: "2026-05-01",
      to: "2026-05-01"
    )

    next_link = pagination_link("次へ")

    expect(response).to have_http_status(:ok)
    expect(disabled_pagination_control("前へ")).to be_present
    expect(next_link).to be_present
    expect(next_link["title"]).to eq("既読確認内訳の2ページ目へ進む（2ページ中、1ページ200件）")
    expect(next_link["aria-label"]).to eq("既読確認内訳の2ページ目へ進む（2ページ中、1ページ200件）")
    expect(next_link["href"]).to include("project_id=#{project.id}")
    expect(next_link["href"]).to include("document_slug=#{document.slug}")
    expect(next_link["href"]).to include("company_id=#{company.id}")
    expect(next_link["href"]).to include("user_id=#{viewer.id}")
    expect(next_link["href"]).to include("from=2026-05-01")
    expect(next_link["href"]).to include("to=2026-05-01")
    expect(next_link["href"]).to include("page=2")

    get admin_read_confirmations_path(
      project_id: project.id,
      document_slug: document.slug,
      company_id: company.id,
      user_id: viewer.id,
      from: "2026-05-01",
      to: "2026-05-01",
      page: 2
    )

    previous_link = pagination_link("前へ")

    expect(response).to have_http_status(:ok)
    expect(previous_link).to be_present
    expect(previous_link["title"]).to eq("既読確認内訳の1ページ目へ戻る（2ページ中、1ページ200件）")
    expect(previous_link["aria-label"]).to eq("既読確認内訳の1ページ目へ戻る（2ページ中、1ページ200件）")
    expect(previous_link["href"]).to include("project_id=#{project.id}")
    expect(previous_link["href"]).to include("document_slug=#{document.slug}")
    expect(previous_link["href"]).to include("company_id=#{company.id}")
    expect(previous_link["href"]).to include("user_id=#{viewer.id}")
    expect(previous_link["href"]).to include("from=2026-05-01")
    expect(previous_link["href"]).to include("to=2026-05-01")
    expect(previous_link["href"]).to include("page=1")
    expect(disabled_pagination_control("次へ")).to be_present
  end
end
