require "rails_helper"

RSpec.describe "Admin document usage reports", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:external_user) { create(:user, :external) }
  let(:company_master_admin) { create(:user, :external, :company_master_admin) }
  let(:project) { create(:project, code: "USAGE", name: "Usage Project") }
  let(:company) { create(:company) }
  let(:viewer) { create(:user, :external, company:) }
  let(:document) { create(:document, project:, title: "Manual", slug: "manual") }

  def page_text
    Nokogiri::HTML(response.body).text.squish
  end

  it "shows a prompt when no project is selected" do
    sign_in_as(admin_user)

    get admin_document_usage_reports_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("文書利用状況")
    expect(page_text).to include("案件を選択すると集計結果を表示します。")
  end

  it "shows usage summary for the selected project" do
    create(:access_log, project:, document:, user: viewer, company:, action_type: :view, accessed_at: Time.zone.local(2026, 5, 1, 10, 0, 0))
    create(:access_log, project:, document:, user: viewer, company:, action_type: :download, accessed_at: Time.zone.local(2026, 5, 1, 11, 0, 0))
    create(:read_confirmation, document:, user: viewer, confirmed_at: Time.zone.local(2026, 5, 1, 12, 0, 0))

    sign_in_as(admin_user)

    get admin_document_usage_reports_path(project_id: project.id)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Usage Project")
    expect(page_text).to include("Manual")
    expect(page_text).to include("閲覧: 1")
    expect(page_text).to include("ダウンロード: 1")
    expect(page_text).to include("既読確認: 1")
  end

  it "forbids external users and company master admins" do
    sign_in_as(external_user)
    get admin_document_usage_reports_path
    expect(response).to have_http_status(:forbidden)

    sign_in_as(company_master_admin)
    get admin_document_usage_reports_path
    expect(response).to have_http_status(:forbidden)
  end
end
