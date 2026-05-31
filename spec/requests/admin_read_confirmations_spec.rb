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

  it "filters read confirmations by document slug" do
    other_document = create(:document, project:, title: "Policy", slug: "policy")
    create(:read_confirmation, document:, user: viewer, confirmed_at: Time.zone.local(2026, 5, 1, 12, 0, 0))
    create(:read_confirmation, document: other_document, user: create(:user, :external, name: "Reader Two"), confirmed_at: Time.zone.local(2026, 5, 2, 12, 0, 0))

    sign_in_as(admin_user)

    get admin_read_confirmations_path(project_id: project.id, document_slug: document.slug)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("文書URL識別子: manual / 文書名: Manual")
    expect(page_text).to include("表示中: 1件")
    expect(page_text).to include("Manual")
    expect(page_text).to include("Reader One")
    expect(page_text).not_to include("Policy")
  end

  it "shows an empty state when the document slug does not belong to the project" do
    document
    sign_in_as(admin_user)

    get admin_read_confirmations_path(project_id: project.id, document_slug: "missing")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("指定した文書はこの案件に見つかりません。")
    expect(page_text).to include("既読確認はありません")
    expect(page_text).to include("表示中: 0件")
  end

  it "prompts for a project when none is selected" do
    project
    sign_in_as(admin_user)

    get admin_read_confirmations_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("案件を選択すると既読確認の内訳を表示します。")
    expect(parsed_html.at_css("select[name='project_id']")).to be_present
    expect(parsed_html.at_css("input[name='document_slug']")).to be_present
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
