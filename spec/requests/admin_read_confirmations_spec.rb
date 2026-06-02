require "rails_helper"

RSpec.describe "Admin read confirmations", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:external_user) { create(:user, :external) }
  let(:company_master_admin) { create(:user, :external, :company_master_admin) }
  let(:project) { create(:project, code: "USAGE", name: "Usage Project") }
  let(:other_project) { create(:project, code: "OTHER", name: "Other Project") }
  let(:company) { create(:company, name: "Client A", domain: "client-a.example") }
  let(:viewer) { create(:user, :external, company:, name: "Reader One", email_address: "reader@example.com") }
  let(:document) { create(:document, project:, title: "Manual", slug: "manual") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def read_confirmation_rows
    parsed_html.css("table tbody tr")
  end

  it "shows project read confirmation details to internal admins" do
    other_document = create(:document, project:, title: "Policy", slug: "policy")
    outside_document = create(:document, project: other_project, title: "Outside", slug: "outside")
    create(:read_confirmation, document:, user: viewer, confirmed_at: Time.zone.local(2026, 5, 1, 12, 0, 0))
    create(:read_confirmation, document: other_document, user: create(:user, :external, name: "Reader Two"), confirmed_at: Time.zone.local(2026, 5, 2, 12, 0, 0))
    create(:read_confirmation, document: outside_document, user: create(:user, :external, name: "Outside Reader"), confirmed_at: Time.zone.local(2026, 5, 3, 12, 0, 0))

    sign_in_as(admin_user)

    get admin_read_confirmations_path(project_id: project.id)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("既読確認内訳")
    expect(page_text).to include("Usage Project")
    expect(page_text).to include("表示中: 2件")
    expect(page_text).to include("Manual")
    expect(page_text).to include("Policy")
    expect(page_text).to include("Reader One / reader@example.com")
    expect(page_text).to include("Client A")
    expect(page_text).not_to include("Outside")
    expect(page_text).not_to include("Outside Reader")

    usage_report_link = parsed_html.at_css("a[href='#{admin_document_usage_reports_path(project_id: project.id)}']")
    expect(usage_report_link).to be_present
    expect(usage_report_link.text).to eq("文書利用状況へ")
  end

  it "filters read confirmations by document slug within the selected project" do
    other_document = create(:document, project:, title: "Policy", slug: "policy")
    outside_same_slug = create(:document, project: other_project, title: "Outside Manual", slug: "manual")
    create(:read_confirmation, document:, user: viewer, confirmed_at: Time.zone.local(2026, 5, 1, 12, 0, 0))
    create(:read_confirmation, document: other_document, user: create(:user, :external, name: "Reader Two"), confirmed_at: Time.zone.local(2026, 5, 2, 12, 0, 0))
    create(:read_confirmation, document: outside_same_slug, user: create(:user, :external, name: "Outside Reader"), confirmed_at: Time.zone.local(2026, 5, 3, 12, 0, 0))

    sign_in_as(admin_user)

    get admin_read_confirmations_path(project_id: project.id, document_slug: document.slug)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("文書URL識別子: manual / 文書名: Manual")
    expect(page_text).to include("表示中: 1件")
    expect(page_text).to include("Manual")
    expect(page_text).to include("Reader One")
    expect(page_text).not_to include("Policy")
    expect(page_text).not_to include("Outside Manual")
    expect(page_text).not_to include("Outside Reader")
    expect(read_confirmation_rows.size).to eq(1)
  end

  it "filters read confirmations by confirmed_at range while keeping document slug filtering" do
    other_document = create(:document, project:, title: "Policy", slug: "policy")
    create(:read_confirmation, document:, user: create(:user, :external, name: "Manual Before"), confirmed_at: Time.zone.local(2026, 4, 30, 23, 59, 59))
    create(:read_confirmation, document:, user: create(:user, :external, name: "Manual Start"), confirmed_at: Time.zone.local(2026, 5, 1, 0, 0, 0))
    create(:read_confirmation, document:, user: create(:user, :external, name: "Manual End"), confirmed_at: Time.zone.local(2026, 5, 3, 23, 59, 59))
    create(:read_confirmation, document:, user: create(:user, :external, name: "Manual After"), confirmed_at: Time.zone.local(2026, 5, 4, 0, 0, 0))
    create(:read_confirmation, document: other_document, user: create(:user, :external, name: "Policy In Range"), confirmed_at: Time.zone.local(2026, 5, 2, 12, 0, 0))

    sign_in_as(admin_user)

    get admin_read_confirmations_path(project_id: project.id, document_slug: document.slug, from: "2026-05-01", to: "2026-05-03")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("既読確認日時の期間: 2026-05-01 から 2026-05-03 まで")
    expect(page_text).to include("文書利用状況の閲覧・ダウンロード集計期間とは別の条件です")
    expect(page_text).to include("表示中: 2件")
    expect(page_text).to include("Manual Start")
    expect(page_text).to include("Manual End")
    expect(page_text).not_to include("Manual Before")
    expect(page_text).not_to include("Manual After")
    expect(page_text).not_to include("Policy In Range")
    expect(parsed_html.at_css("input[name='from']")["value"]).to eq("2026-05-01")
    expect(parsed_html.at_css("input[name='to']")["value"]).to eq("2026-05-03")
  end

  it "supports one-sided confirmed_at filters and ignores invalid dates" do
    create(:read_confirmation, document:, user: create(:user, :external, name: "Earlier Reader"), confirmed_at: Time.zone.local(2026, 5, 1, 12, 0, 0))
    create(:read_confirmation, document:, user: create(:user, :external, name: "Boundary Reader"), confirmed_at: Time.zone.local(2026, 5, 2, 12, 0, 0))
    create(:read_confirmation, document:, user: create(:user, :external, name: "Later Reader"), confirmed_at: Time.zone.local(2026, 5, 3, 12, 0, 0))

    sign_in_as(admin_user)

    get admin_read_confirmations_path(project_id: project.id, from: "2026-05-02")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Boundary Reader")
    expect(page_text).to include("Later Reader")
    expect(page_text).not_to include("Earlier Reader")

    get admin_read_confirmations_path(project_id: project.id, to: "2026-05-02")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Earlier Reader")
    expect(page_text).to include("Boundary Reader")
    expect(page_text).not_to include("Later Reader")

    get admin_read_confirmations_path(project_id: project.id, from: "not-a-date", to: "2026-05-02")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Earlier Reader")
    expect(page_text).to include("Boundary Reader")
    expect(page_text).not_to include("Later Reader")
  end

  it "shows an empty state when the document slug does not belong to the project" do
    create(:read_confirmation, document:, user: viewer, confirmed_at: Time.zone.local(2026, 5, 1, 12, 0, 0))
    sign_in_as(admin_user)

    get admin_read_confirmations_path(project_id: project.id, document_slug: "missing")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("指定した文書はこの案件に見つかりません。")
    expect(page_text).to include("既読確認はありません")
    expect(page_text).to include("表示中: 0件")
    expect(page_text).to include("指定した文書URL識別子に一致する文書がないため、既読確認は表示されません。")
    expect(page_text).not_to include("Reader One / reader@example.com")
    expect(read_confirmation_rows).to be_empty
  end

  it "prompts for a project without leaking read confirmation rows when none is selected" do
    create(:read_confirmation, document:, user: viewer, confirmed_at: Time.zone.local(2026, 5, 1, 12, 0, 0))
    sign_in_as(admin_user)

    get admin_read_confirmations_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("案件を選択すると既読確認の内訳を表示します。")
    expect(page_text).not_to include("Manual")
    expect(page_text).not_to include("Reader One / reader@example.com")
    expect(parsed_html.at_css("select[name='project_id']")).to be_present
    expect(parsed_html.at_css("input[name='document_slug']")).to be_present
    expect(parsed_html.at_css("input[name='from'][type='date']")).to be_present
    expect(parsed_html.at_css("input[name='to'][type='date']")).to be_present
    expect(read_confirmation_rows).to be_empty
  end

  it "limits the selected project results to the latest 200 confirmations" do
    base_time = Time.zone.local(2026, 5, 1, 9, 0, 0)

    201.times do |index|
      limited_document = create(:document, project:, title: "Limited Manual #{index}", slug: "limited-manual-#{index}")
      create(:read_confirmation, document: limited_document, user: viewer, confirmed_at: base_time + index.minutes)
    end

    sign_in_as(admin_user)

    get admin_read_confirmations_path(project_id: project.id)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示中: 200件")
    expect(read_confirmation_rows.size).to eq(200)
    expect(page_text).to include("Limited Manual 200")
    expect(page_text).to include("Limited Manual 1")
    expect(page_text).not_to include("Limited Manual 0")
  end

  it "applies the latest 200 confirmation limit after the confirmed_at date filter" do
    base_time = Time.zone.local(2026, 5, 1, 9, 0, 0)
    create(:read_confirmation, document: create(:document, project:, title: "Outside Period Latest", slug: "outside-period-latest"), user: viewer, confirmed_at: Time.zone.local(2026, 5, 2, 9, 0, 0))

    201.times do |index|
      limited_document = create(:document, project:, title: "Period Manual #{index}", slug: "period-manual-#{index}")
      create(:read_confirmation, document: limited_document, user: viewer, confirmed_at: base_time + index.minutes)
    end

    sign_in_as(admin_user)

    get admin_read_confirmations_path(project_id: project.id, from: "2026-05-01", to: "2026-05-01")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示中: 200件")
    expect(read_confirmation_rows.size).to eq(200)
    expect(page_text).to include("Period Manual 200")
    expect(page_text).to include("Period Manual 1")
    expect(page_text).not_to include("Period Manual 0")
    expect(page_text).not_to include("Outside Period Latest")
  end

  it "forbids external users and company master admins" do
    sign_in_as(external_user)
    get admin_read_confirmations_path(project_id: project.id)
    expect(response).to have_http_status(:forbidden)

    sign_in_as(company_master_admin)
    get admin_read_confirmations_path(project_id: project.id)
    expect(response).to have_http_status(:forbidden)
  end
end
