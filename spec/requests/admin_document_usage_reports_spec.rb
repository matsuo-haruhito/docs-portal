require "rails_helper"

RSpec.describe "Admin document usage reports", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:external_user) { create(:user, :external) }
  let(:company_master_admin) { create(:user, :external, :company_master_admin) }
  let(:project) { create(:project, code: "USAGE", name: "Usage Project") }
  let(:company) { create(:company) }
  let(:viewer) { create(:user, :external, company:) }
  let(:document) { create(:document, project:, title: "Manual", slug: "manual") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def normalized_text(node)
    node.text.gsub(/\s+/, " ").strip
  end

  it "shows a prompt when no project is selected" do
    sign_in_as(admin_user)

    get admin_document_usage_reports_path

    expect(response).to have_http_status(:ok)
    expect(parsed_html.at_css("h1")&.text).to include("文書利用状況")
    expect(parsed_html.at_css("p.muted")&.text).to include("案件を選択すると集計結果を表示します。")
  end

  it "shows usage summary for the selected project" do
    create(:access_log, project:, document:, user: viewer, company:, action_type: :view, accessed_at: Time.zone.local(2026, 5, 1, 10, 0, 0))
    create(:access_log, project:, document:, user: viewer, company:, action_type: :download, accessed_at: Time.zone.local(2026, 5, 1, 11, 0, 0))
    create(:read_confirmation, document:, user: viewer, confirmed_at: Time.zone.local(2026, 5, 1, 12, 0, 0))

    sign_in_as(admin_user)

    get admin_document_usage_reports_path(project_id: project.id)

    expect(response).to have_http_status(:ok)

    summary_card = parsed_html.css("section.card").find do |section|
      normalized_text(section.at_css("h2")).include?("集計サマリ")
    end

    expect(summary_card).to be_present

    summary_lines = summary_card.css("p").map { normalized_text(_1) }

    expect(summary_lines).to include("案件: Usage Project (USAGE)")
    expect(summary_lines).to include("閲覧: 1 / ダウンロード: 1 / 既読確認: 1")

    document_row = parsed_html.css("table tbody tr").find do |row|
      normalized_text(row.at_css("td")) == "Manual"
    end

    expect(document_row).to be_present

    cells = document_row.css("td").map { normalized_text(_1) }

    expect(cells[0]).to eq("Manual")
    expect(cells[4]).to eq("あり")
    expect(cells[5..7]).to eq(%w[1 1 1])
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
