require "csv"
require "rails_helper"

RSpec.describe "Admin read confirmations safety contracts", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "READ", name: "Read Project") }
  let(:other_project) { create(:project, code: "OTHER", name: "Other Project") }
  let(:company) { create(:company, name: "Client A", domain: "client-a.example") }
  let(:viewer) { create(:user, :external, company:, name: "Reader One", email_address: "reader@example.com") }
  let(:document) { create(:document, project:, title: "Read Manual", slug: "read-manual") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def read_confirmation_rows
    parsed_html.css("table tbody tr").map { _1.text.squish }
  end

  def parsed_csv
    CSV.parse(response.body, headers: true)
  end

  it "keeps unmatched document filters isolated to the selected project in HTML and CSV" do
    outside_document = create(:document, project: other_project, title: "Outside Manual", slug: "outside-manual")
    outside_reader = create(:user, :external, name: "Outside Reader", email_address: "outside@example.com")
    create(:read_confirmation, document:, user: viewer, confirmed_at: Time.zone.local(2026, 5, 1, 12, 0, 0))
    create(:read_confirmation, document: outside_document, user: outside_reader, confirmed_at: Time.zone.local(2026, 5, 2, 12, 0, 0))

    sign_in_as(admin_user)

    get admin_read_confirmations_path(project_id: project.id, document_slug: outside_document.slug)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("指定した文書はこの案件に見つかりません。")
    expect(page_text).to include("表示中: 0件")
    expect(page_text).not_to include("Outside Manual")
    expect(page_text).not_to include("Outside Reader")
    expect(read_confirmation_rows).to be_empty

    get admin_read_confirmations_path(project_id: project.id, document_slug: outside_document.slug, format: :csv)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/csv")
    expect(parsed_csv.size).to eq(0)
    expect(response.body).not_to include("Outside Manual")
    expect(response.body).not_to include("outside@example.com")
  end

  it "keeps candidate-out company and user filters empty in CSV" do
    outside_company = create(:company, name: "Outside Client", domain: "outside.example")
    outside_document = create(:document, project: other_project, title: "Outside Manual", slug: "outside-manual")
    outside_reader = create(:user, :external, company: outside_company, name: "Outside Reader", email_address: "outside@example.com")
    create(:read_confirmation, document:, user: viewer, confirmed_at: Time.zone.local(2026, 5, 1, 12, 0, 0))
    create(:read_confirmation, document: outside_document, user: outside_reader, confirmed_at: Time.zone.local(2026, 5, 2, 12, 0, 0))

    sign_in_as(admin_user)

    get admin_read_confirmations_path(project_id: project.id, company_id: outside_company.id, format: :csv)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/csv")
    expect(parsed_csv.size).to eq(0)
    expect(response.body).not_to include("Read Manual")
    expect(response.body).not_to include("Outside Manual")

    get admin_read_confirmations_path(project_id: project.id, user_id: outside_reader.id, format: :csv)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/csv")
    expect(parsed_csv.size).to eq(0)
    expect(response.body).not_to include("reader@example.com")
    expect(response.body).not_to include("outside@example.com")
  end

  it "treats invalid projects as unselected and never exports all confirmations" do
    create(:read_confirmation, document:, user: viewer, confirmed_at: Time.zone.local(2026, 5, 1, 12, 0, 0))
    invalid_project_id = [project.id, other_project.id].max + 1000

    sign_in_as(admin_user)

    get admin_read_confirmations_path(project_id: invalid_project_id)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("案件を選択してください")
    expect(page_text).not_to include("Read Manual")
    expect(page_text).not_to include("Reader One / reader@example.com")
    expect(read_confirmation_rows).to be_empty

    get admin_read_confirmations_path(project_id: invalid_project_id, format: :csv)

    expect(response).to redirect_to(admin_read_confirmations_path)

    follow_redirect!

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("CSV出力には案件選択が必要です。")
    expect(page_text).not_to include("Read Manual")
    expect(page_text).not_to include("Reader One / reader@example.com")
  end
end
