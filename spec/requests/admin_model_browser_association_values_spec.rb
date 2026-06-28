require "rails_helper"

RSpec.describe "Admin model browser association values", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def table_headers
    parsed_html.css("thead th").map { _1.text.squish }
  end

  def table_row_including(text)
    parsed_html.css("tbody tr").find { _1.text.squish.include?(text) }
  end

  it "shows a readable company label next to project company ids" do
    company = create(:company, name: "Client Alpha")
    project = create(:project, company:, code: "ASSOC4107", name: "Association Project")

    sign_in_as(admin_user)
    get admin_model_browser_model_path("projects")

    expect(response).to have_http_status(:ok)

    row_text = table_row_including(project.code).text.squish
    expect(table_headers).to include("会社")
    expect(row_text).to include("Client Alpha（ID: #{company.id}）")
  end

  it "shows a readable user label next to project membership user ids" do
    project = create(:project, code: "MEMB4107", name: "Membership Project")
    user = create(:user, :external, name: "External Reviewer", email_address: "reviewer@example.com")
    membership = create(:project_membership, project:, user:)

    sign_in_as(admin_user)
    get admin_model_browser_model_path("project_memberships")

    expect(response).to have_http_status(:ok)

    row_text = table_row_including(membership.public_id).text.squish
    expect(table_headers).to include("ユーザー")
    expect(row_text).to include("External Reviewer（ID: #{user.id}）")
  end
end
