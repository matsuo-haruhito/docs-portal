require "rails_helper"

RSpec.describe "Admin access log filter candidates", type: :request do
  let(:admin_company) { create(:company, domain: "audit-admin.example.com", name: "Audit Admin Company") }
  let(:admin_user) { create(:user, :internal, company: admin_company, email_address: "admin@example.com") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def filter_option_values(name)
    parsed_html.css(%(select[name="#{name}"] option)).map { _1["value"].to_s }
  end

  def filter_record_option_values(name)
    filter_option_values(name).reject(&:blank?)
  end

  def selected_filter_option(name, value)
    parsed_html.at_css(%(select[name="#{name}"] option[value="#{value}"][selected]))
  end

  before do
    sign_in_as(admin_user)
  end

  it "bounds project, company, and user filter candidates" do
    projects = 55.times.map { |index| create(:project, code: "CAND#{index.to_s.rjust(3, '0')}", name: "Candidate Project #{index}") }
    companies = 55.times.map { |index| create(:company, domain: "candidate-#{index.to_s.rjust(3, '0')}.example.com", name: "Candidate Company #{index}") }
    users = 55.times.map { |index| create(:user, :internal, company: companies.first, email_address: "candidate-#{index.to_s.rjust(3, '0')}@example.com") }

    get admin_access_logs_path

    expect(response).to have_http_status(:ok)
    expect(filter_record_option_values("project_id").size).to eq(50)
    expect(filter_record_option_values("company_id").size).to eq(50)
    expect(filter_record_option_values("user_id").size).to eq(50)
    expect(filter_option_values("project_id")).not_to include(projects.last.id.to_s)
    expect(filter_option_values("company_id")).not_to include(companies.last.id.to_s)
    expect(filter_option_values("user_id")).not_to include(users.last.id.to_s)
  end

  it "keeps selected records visible when they are outside the bounded candidates" do
    55.times do |index|
      create(:project, code: "KEEP#{index.to_s.rjust(3, '0')}", name: "Keep Project #{index}")
      create(:company, domain: "keep-#{index.to_s.rjust(3, '0')}.example.com", name: "Keep Company #{index}")
      create(:user, :internal, company: admin_company, email_address: "keep-#{index.to_s.rjust(3, '0')}@example.com")
    end
    selected_project = create(:project, code: "ZZZ", name: "Selected Project")
    selected_company = create(:company, domain: "zzz-selected.example.com", name: "Selected Company")
    selected_user = create(:user, :internal, company: selected_company, name: "Selected User", email_address: "zzz-selected@example.com")

    get admin_access_logs_path(
      project_id: selected_project.id,
      company_id: selected_company.id,
      user_id: selected_user.id
    )

    expect(response).to have_http_status(:ok)
    expect(filter_record_option_values("project_id").size).to eq(51)
    expect(filter_record_option_values("company_id").size).to eq(51)
    expect(filter_record_option_values("user_id").size).to eq(51)
    expect(selected_filter_option("project_id", selected_project.id)).to be_present
    expect(selected_filter_option("company_id", selected_company.id)).to be_present
    expect(selected_filter_option("user_id", selected_user.id)).to be_present
    expect(page_text).to include("案件: ZZZ / Selected Project")
    expect(page_text).to include("会社: Selected Company / zzz-selected.example.com")
    expect(page_text).to include("ユーザー: Selected User / zzz-selected@example.com")
  end

  it "keeps invalid record ids from creating selected options while preserving fallback summaries" do
    get admin_access_logs_path(project_id: "999999", company_id: "888888", user_id: "777777")

    expect(response).to have_http_status(:ok)
    expect(selected_filter_option("project_id", "999999")).to be_nil
    expect(selected_filter_option("company_id", "888888")).to be_nil
    expect(selected_filter_option("user_id", "777777")).to be_nil
    expect(page_text).to include("案件: 指定あり")
    expect(page_text).to include("会社: 指定あり")
    expect(page_text).to include("ユーザー: 指定あり")
  end
end
