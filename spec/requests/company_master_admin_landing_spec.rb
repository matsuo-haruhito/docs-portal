require "rails_helper"

RSpec.describe "Company master admin landing", type: :request do
  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def action_targets
    parsed_html.css("a[href], form[action]").map { |node| node["href"] || node["action"] }
  end

  it "separates allowed company/user actions from internal admin handoff items" do
    company = create(:company, name: "Alpha", domain: "alpha.example.com")
    sign_in_as(create(:user, :external, :company_master_admin, company:))

    get admin_root_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("ここから直接移動できるのは、会社管理者として操作できる次の 2 画面だけです")
    expect(page_text).to include("会社を管理")
    expect(page_text).to include("ユーザーを管理")
    expect(page_text).to include("次の項目は依頼前の確認リストです。この画面からは移動できず")
    expect(page_text).to include("案件・案件所属")
    expect(page_text).to include("文書・文書権限")
    expect(page_text).to include("運用確認")
    expect(page_text).to include("管理者判断")
    expect(page_text).to include("会社管理者の権限や文書閲覧範囲を広げるものではありません")

    expect(action_targets).to include(admin_companies_path, admin_users_path)
    expect(action_targets).not_to include(
      admin_projects_path,
      admin_project_memberships_path,
      admin_documents_path,
      admin_document_permissions_path,
      admin_access_logs_path,
      admin_document_usage_reports_path
    )
    expect(action_targets).not_to include(a_string_starting_with("mailto:"))
  end
end
