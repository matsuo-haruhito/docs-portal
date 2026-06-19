# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin access log remote filters", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:external_user) { create(:user, :external) }

  def json_body
    JSON.parse(response.body)
  end

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def selected_filter_value(name)
    selected_option = parsed_html.at_css(%(select[name="#{name}"] option[selected]))
    selected_option&.[]("value") || parsed_html.at_css(%(input[name="#{name}"]))&.[]("value")
  end

  before do
    sign_in_as(admin_user)
  end

  it "renders remote combobox filters and restores selected values outside bounded candidates" do
    55.times { |index| create(:project, code: format("P%02d", index), name: "Project #{index}") }
    55.times { |index| create(:company, domain: format("company%02d.example.com", index), name: "Company #{index}") }
    55.times { |index| create(:user, :internal, email_address: format("user%02d@example.com", index), name: "User #{index}") }
    selected_project = create(:project, code: "ZZZ", name: "Zeta Project")
    selected_company = create(:company, domain: "zzz.example.com", name: "Zeta Company")
    selected_user = create(:user, :internal, email_address: "zzz-user@example.com", name: "Zeta User")

    get admin_access_logs_path(project_id: selected_project.id, company_id: selected_company.id, user_id: selected_user.id)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("条件に一致する監査ログはありません。")
    expect(response.body).to include(project_search_admin_access_logs_path(format: :json))
    expect(response.body).to include(selected_project_admin_access_logs_path(format: :json))
    expect(response.body).to include(company_search_admin_access_logs_path(format: :json))
    expect(response.body).to include(selected_company_admin_access_logs_path(format: :json))
    expect(response.body).to include(user_search_admin_access_logs_path(format: :json))
    expect(response.body).to include(selected_user_admin_access_logs_path(format: :json))
    expect(selected_filter_value("project_id")).to eq(selected_project.id.to_s)
    expect(selected_filter_value("company_id")).to eq(selected_company.id.to_s)
    expect(selected_filter_value("user_id")).to eq(selected_user.id.to_s)
    expect(page_text).to include("案件: ZZZ / Zeta Project")
    expect(page_text).to include("会社: Zeta Company / zzz.example.com")
    expect(page_text).to include("ユーザー: Zeta User / zzz-user@example.com")
  end

  it "returns bounded project, company, and user search options" do
    alpha_project = create(:project, code: "ALPHA", name: "Alpha Project")
    create(:project, code: "BETA", name: "Beta Project")
    alpha_company = create(:company, domain: "alpha.example.com", name: "Alpha Company")
    create(:company, domain: "beta.example.com", name: "Beta Company")
    alpha_user = create(:user, :internal, email_address: "alpha-user@example.com", name: "Alpha User")
    create(:user, :internal, email_address: "beta-user@example.com", name: "Beta User")

    get project_search_admin_access_logs_path(format: :json), params: { q: "alp" }
    expect(json_body.fetch("options")).to contain_exactly(include("value" => alpha_project.id, "text" => "ALPHA / Alpha Project"))

    get company_search_admin_access_logs_path(format: :json), params: { q: "alpha.example" }
    expect(json_body.fetch("options")).to contain_exactly(include("value" => alpha_company.id, "text" => "Alpha Company / alpha.example.com"))

    get user_search_admin_access_logs_path(format: :json), params: { q: "alpha-user" }
    expect(json_body.fetch("options")).to contain_exactly(include("value" => alpha_user.id, "text" => "Alpha User / alpha-user@example.com"))
  end

  it "returns selected filter options and nil for missing selected ids" do
    project = create(:project, code: "SEL", name: "Selected Project")
    company = create(:company, domain: "selected.example.com", name: "Selected Company")
    user = create(:user, :internal, email_address: "selected-user@example.com", name: "Selected User")

    get selected_project_admin_access_logs_path(format: :json), params: { id: project.id }
    expect(json_body.fetch("option")).to include("value" => project.id, "text" => "SEL / Selected Project")

    get selected_company_admin_access_logs_path(format: :json), params: { id: company.id }
    expect(json_body.fetch("option")).to include("value" => company.id, "text" => "Selected Company / selected.example.com")

    get selected_user_admin_access_logs_path(format: :json), params: { id: user.id }
    expect(json_body.fetch("option")).to include("value" => user.id, "text" => "Selected User / selected-user@example.com")

    get selected_project_admin_access_logs_path(format: :json), params: { id: "999999" }
    expect(json_body.fetch("option")).to be_nil
  end

  it "bounds blank and overlong remote search queries" do
    22.times { |index| create(:project, code: format("BLANK%02d", index), name: "Blank Candidate #{index}") }
    normalized_query = "a" * Admin::AccessLogsController::ACCESS_LOG_QUERY_MAX_LENGTH
    long_project = create(:project, code: "LONG", name: normalized_query)

    get project_search_admin_access_logs_path(format: :json), params: { q: "" }
    expect(json_body.fetch("options").size).to eq(Admin::AccessLogsController::FILTER_SEARCH_LIMIT)

    get project_search_admin_access_logs_path(format: :json), params: { q: "  #{normalized_query}ignored-suffix  " }
    expect(json_body.fetch("options")).to contain_exactly(include("value" => long_project.id, "text" => "LONG / #{normalized_query}"))
  end

  it "keeps admin-only authorization on remote filter endpoints" do
    sign_in_as(external_user)

    get project_search_admin_access_logs_path(format: :json), params: { q: "project" }

    expect(response).to have_http_status(:forbidden)
  end
end
