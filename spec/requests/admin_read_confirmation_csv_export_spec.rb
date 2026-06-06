require "rails_helper"
require "csv"

RSpec.describe "Admin read confirmation CSV export", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "USAGE", name: "Usage Project") }
  let(:other_project) { create(:project, code: "OTHER", name: "Other Project") }
  let(:company) { create(:company, name: "Client A", domain: "client-a.example") }
  let(:other_company) { create(:company, name: "Client B", domain: "client-b.example") }
  let(:viewer) { create(:user, :external, company:, name: "Reader One", email_address: "reader@example.com") }
  let(:other_viewer) { create(:user, :external, company: other_company, name: "Reader Two", email_address: "reader-two@example.com") }
  let(:document) { create(:document, project:, title: "Manual", slug: "manual") }
  let(:other_document) { create(:document, project:, title: "Policy", slug: "policy") }

  def csv_rows
    CSV.parse(response.body, headers: true)
  end

  it "exports the current project filters with fixed headers and filename" do
    create(:read_confirmation, document:, user: viewer, confirmed_at: Time.zone.local(2026, 5, 2, 10, 30, 0))
    create(:read_confirmation, document: other_document, user: other_viewer, confirmed_at: Time.zone.local(2026, 5, 2, 11, 30, 0))
    create(:read_confirmation, document: create(:document, project: other_project, title: "Outside", slug: "outside"), user: viewer, confirmed_at: Time.zone.local(2026, 5, 2, 12, 30, 0))

    sign_in_as(admin_user)

    get admin_read_confirmations_path(format: :csv), params: {
      project_id: project.id,
      document_slug: document.slug,
      company_id: company.id,
      user_id: viewer.id,
      from: "2026-05-02",
      to: "2026-05-02"
    }

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/csv")
    expect(response.headers["Content-Disposition"]).to include("read-confirmations-USAGE-")
    expect(csv_rows.headers).to eq(["確認日時", "文書名", "document slug", "確認者", "email", "会社"])
    expect(csv_rows.size).to eq(1)
    expect(csv_rows.first.to_h).to include(
      "確認日時" => "2026-05-02 10:30:00",
      "文書名" => "Manual",
      "document slug" => "manual",
      "確認者" => "Reader One",
      "email" => "reader@example.com",
      "会社" => "Client A"
    )
    expect(csv_rows.map { _1["文書名"] }).not_to include("Policy", "Outside")
  end

  it "does not export a cross-project CSV when project is not selected" do
    create(:read_confirmation, document:, user: viewer, confirmed_at: Time.zone.local(2026, 5, 2, 10, 30, 0))

    sign_in_as(admin_user)

    get admin_read_confirmations_path(format: :csv)

    expect(response).to redirect_to(admin_read_confirmations_path)
    expect(flash[:alert]).to eq("CSV出力には案件選択が必要です。")
  end

  it "keeps the latest 200 confirmation boundary in CSV exports" do
    base_time = Time.zone.local(2026, 5, 1, 9, 0, 0)

    201.times do |index|
      limited_document = create(:document, project:, title: "Limited Manual #{index}", slug: "limited-manual-#{index}")
      create(:read_confirmation, document: limited_document, user: viewer, confirmed_at: base_time + index.minutes)
    end

    sign_in_as(admin_user)

    get admin_read_confirmations_path(format: :csv), params: { project_id: project.id }

    expect(response).to have_http_status(:ok)
    expect(csv_rows.size).to eq(Admin::ReadConfirmationsController::DISPLAY_LIMIT)
    expect(csv_rows.map { _1["文書名"] }).to include("Limited Manual 200", "Limited Manual 1")
    expect(csv_rows.map { _1["文書名"] }).not_to include("Limited Manual 0")
  end
end
