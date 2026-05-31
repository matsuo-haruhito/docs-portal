require "rails_helper"

RSpec.describe "Admin projects table preferences", type: :request do
  let(:admin) { create(:user, :admin) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def project_column_keys
    parsed_html.css('[data-rails-table-preferences-column-key]').map { |node| node["data-rails-table-preferences-column-key"] }.uniq
  end

  it "renders the admin_projects editor and stable project column keys when projects exist" do
    company = create(:company, name: "Example Corp", domain: "example.test")
    create(:project, code: "ALPHA", name: "Alpha Project", company:, description: "First project", active: true)
    create(:project, code: "OMEGA", name: "Omega Project", description: "Archived project", active: false)
    sign_in_as(admin)

    get admin_projects_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("案件一覧の表示設定")
    expect(response.body).to include("admin_projects")
    expect(project_column_keys).to contain_exactly("code", "name", "company", "description", "status", "actions")
    expect(page_text).to include("ALPHA")
    expect(page_text).to include("Example Corp")
    expect(page_text).to include("未設定")
    expect(page_text).to include("有効")
    expect(page_text).to include("無効")
  end

  it "keeps the empty state without rendering the preferences table" do
    sign_in_as(admin)

    get admin_projects_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("まだ案件は登録されていません。")
    expect(response.body).not_to include("案件一覧の表示設定")
    expect(project_column_keys).to be_empty
  end
end
