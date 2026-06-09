require "csv"
require "rails_helper"

RSpec.describe "Admin read confirmations pagination", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "PAGED", name: "Paged Project") }
  let(:other_project) { create(:project, code: "OTHER", name: "Other Project") }
  let(:company) { create(:company, name: "Paged Client", domain: "paged-client.example") }
  let(:viewer) { create(:user, :external, company:, name: "Paged Reader", email_address: "paged-reader@example.com") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def read_confirmation_rows
    parsed_html.css("table tbody tr").map { _1.text.squish }
  end

  def link_by_text(text)
    parsed_html.css("a").find { _1.text.squish == text }
  end

  def csv_export_link
    link_by_text("CSV出力")
  end

  def create_paged_confirmation(number, confirmed_at:)
    document = create(:document, project:, title: "Paged Manual #{number}", slug: "paged-manual-#{number}")
    create(:read_confirmation, document:, user: viewer, confirmed_at:)
  end

  it "moves beyond the first 200 confirmations while keeping a bounded page size" do
    base_time = Time.zone.local(2026, 5, 1, 9, 0, 0)
    201.times { |index| create_paged_confirmation(index, confirmed_at: base_time + index.minutes) }

    sign_in_as(admin_user)

    get admin_read_confirmations_path(project_id: project.id)

    expect(response).to have_http_status(:ok)
    expect(read_confirmation_rows.size).to eq(Admin::ReadConfirmationsController::DISPLAY_LIMIT)
    expect(page_text).to include("表示中: 200件")
    expect(page_text).to include("表示範囲: 1-200件目 / 条件一致 201件 / Page 1 / 2")
    expect(read_confirmation_rows.join).to include("Paged Manual 200")
    expect(read_confirmation_rows.join).to include("Paged Manual 1")
    expect(read_confirmation_rows.join).not_to include("Paged Manual 0")

    next_link = link_by_text("次へ")
    expect(next_link).to be_present
    expect(next_link["href"]).to include("project_id=#{project.id}", "page=2")

    get admin_read_confirmations_path(project_id: project.id, page: 2)

    expect(response).to have_http_status(:ok)
    expect(read_confirmation_rows.size).to eq(1)
    expect(page_text).to include("表示中: 1件")
    expect(page_text).to include("表示範囲: 201-201件目 / 条件一致 201件 / Page 2 / 2")
    expect(read_confirmation_rows.join).to include("Paged Manual 0")
    expect(read_confirmation_rows.join).not_to include("Paged Manual 1")

    previous_link = link_by_text("前へ")
    expect(previous_link).to be_present
    expect(previous_link["href"]).to include("project_id=#{project.id}")
    expect(previous_link["href"]).not_to include("page=")
  end

  it "keeps document, company, user, and valid date filters in pagination and CSV links" do
    base_time = Time.zone.local(2026, 5, 1, 9, 0, 0)
    outside_document = create(:document, project: other_project, title: "Outside Manual", slug: "filtered-manual-outside")
    outside_reader = create(:user, :external, name: "Outside Reader", email_address: "outside@example.com")

    201.times do |index|
      document = create(:document, project:, title: "Filtered Manual #{index}", slug: "filtered-manual-#{index}")
      create(:read_confirmation, document:, user: viewer, confirmed_at: base_time + index.minutes)
    end
    create(:read_confirmation, document: outside_document, user: outside_reader, confirmed_at: base_time + 202.minutes)

    sign_in_as(admin_user)

    get admin_read_confirmations_path(
      project_id: project.id,
      document_slug: "filtered-manual",
      company_id: company.id,
      user_id: viewer.id,
      from: "not-a-date",
      to: "2026-05-01",
      page: 2
    )

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("文書URL識別子: filtered-manual / 一致文書: 201件")
    expect(page_text).to include("会社: Paged Client")
    expect(page_text).to include("確認者: Paged Reader / paged-reader@example.com")
    expect(page_text).to include("表示範囲: 201-201件目 / 条件一致 201件 / Page 2 / 2")
    expect(read_confirmation_rows).to contain_exactly(a_string_including("Filtered Manual 0", "Paged Reader / paged-reader@example.com", "Paged Client"))
    expect(page_text).not_to include("Outside Reader")

    previous_link = link_by_text("前へ")
    expect(previous_link["href"]).to include(
      "project_id=#{project.id}",
      "document_slug=filtered-manual",
      "company_id=#{company.id}",
      "user_id=#{viewer.id}",
      "to=2026-05-01"
    )
    expect(previous_link["href"]).not_to include("from=not-a-date")

    expect(csv_export_link["href"]).to include(
      "project_id=#{project.id}",
      "document_slug=filtered-manual",
      "company_id=#{company.id}",
      "user_id=#{viewer.id}",
      "to=2026-05-01",
      "page=2",
      "format=csv"
    )
    expect(csv_export_link["href"]).not_to include("from=not-a-date")
  end

  it "exports only the current read confirmation page" do
    base_time = Time.zone.local(2026, 5, 1, 9, 0, 0)
    201.times { |index| create_paged_confirmation(index, confirmed_at: base_time + index.minutes) }

    sign_in_as(admin_user)

    get admin_read_confirmations_path(project_id: project.id, page: 2, format: :csv)

    csv = CSV.parse(response.body, headers: true)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/csv")
    expect(csv.size).to eq(1)
    expect(csv.first.to_h).to include("文書名" => "Paged Manual 0", "document slug" => "paged-manual-0")
    expect(response.body).not_to include("Paged Manual 1")
  end
end
