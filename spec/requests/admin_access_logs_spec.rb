require "rails_helper"

RSpec.describe "Admin access logs", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:external_user) { create(:user, :external) }
  let(:project) { create(:project, code: "AUDIT", name: "Audit Project") }
  let(:document) { create(:document, project:, title: "Audit Document", slug: "audit-document") }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def log_rows
    parsed_html.css("table tbody tr")
  end

  def log_target_names
    log_rows.filter_map do |row|
      row.at_css("td:nth-child(3) code")&.text&.squish
    end
  end

  def create_access_log!(action_type:, target_type:, target_name:, user: admin_user, company: admin_user.company, project: self.project, document: self.document, document_version: version, accessed_at: Time.current)
    AccessLog.create!(
      user:,
      company:,
      project:,
      document:,
      document_version:,
      action_type:,
      target_type:,
      target_name:,
      ip_address: "127.0.0.1",
      user_agent: "RSpec",
      accessed_at:
    )
  end

  it "shows access logs to internal admins" do
    create_access_log!(action_type: :download, target_type: "zip", target_name: "audit.zip")

    sign_in_as(admin_user)

    get admin_access_logs_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("監査ログ")
    expect(response.body).to include("Audit Project")
    expect(response.body).to include("Audit Document")
    expect(log_target_names).to eq(["audit.zip"])
  end

  it "filters access logs by action type and target type" do
    create_access_log!(action_type: :download, target_type: "zip", target_name: "audit.zip")
    create_access_log!(action_type: :view, target_type: "page", target_name: "index.html")

    sign_in_as(admin_user)

    get admin_access_logs_path(action_type: "download", target_type: "zip")

    expect(response).to have_http_status(:ok)
    expect(log_target_names).to eq(["audit.zip"])
  end

  it "filters access logs by project, company, and user" do
    matching_project = create(:project, code: "FILTER", name: "Filter Project")
    matching_company = create(:company, domain: "filter.example.com", name: "Filter Co")
    matching_user = create(:user, :internal, company: matching_company, email_address: "filter-user@example.com")
    other_project = create(:project, code: "OTHER", name: "Other Project")
    other_company = create(:company, domain: "other.example.com", name: "Other Co")
    other_company_user = create(:user, :internal, company: other_company, email_address: "other-company-user@example.com")
    other_user = create(:user, :internal, company: matching_company, email_address: "other-user@example.com")
    matching_document = create(:document, project: matching_project, title: "Filter Document", slug: "filter-document")
    matching_version = create(:document_version, document: matching_document, version_label: "v2.0.0")
    other_document = create(:document, project: other_project, title: "Other Document", slug: "other-document")
    other_version = create(:document_version, document: other_document, version_label: "v3.0.0")

    create_access_log!(
      action_type: :view,
      target_type: "page",
      target_name: "matching.html",
      user: matching_user,
      company: matching_company,
      project: matching_project,
      document: matching_document,
      document_version: matching_version
    )
    create_access_log!(
      action_type: :view,
      target_type: "page",
      target_name: "other-project.html",
      user: matching_user,
      company: matching_company,
      project: other_project,
      document: other_document,
      document_version: other_version
    )
    create_access_log!(
      action_type: :view,
      target_type: "page",
      target_name: "other-company.html",
      user: other_company_user,
      company: other_company,
      project: matching_project,
      document: matching_document,
      document_version: matching_version
    )
    create_access_log!(
      action_type: :view,
      target_type: "page",
      target_name: "other-user.html",
      user: other_user,
      company: matching_company,
      project: matching_project,
      document: matching_document,
      document_version: matching_version
    )

    sign_in_as(admin_user)

    get admin_access_logs_path(
      project_id: matching_project.id,
      company_id: matching_company.id,
      user_id: matching_user.id
    )

    expect(response).to have_http_status(:ok)
    expect(log_target_names).to eq(["matching.html"])
  end

  it "filters access logs by document title" do
    title_match_document = create(:document, project:, title: "Quarterly Audit Summary", slug: "q1-summary")
    title_match_version = create(:document_version, document: title_match_document, version_label: "v2.0.0")
    other_document = create(:document, project:, title: "Operations Note", slug: "ops-note")
    other_version = create(:document_version, document: other_document, version_label: "v3.0.0")

    create_access_log!(
      action_type: :view,
      target_type: "page",
      target_name: "title-match.html",
      document: title_match_document,
      document_version: title_match_version
    )
    create_access_log!(
      action_type: :view,
      target_type: "page",
      target_name: "title-miss.html",
      document: other_document,
      document_version: other_version
    )

    sign_in_as(admin_user)

    get admin_access_logs_path(document_q: "Quarterly Audit")

    expect(response).to have_http_status(:ok)
    expect(log_target_names).to eq(["title-match.html"])
  end

  it "filters access logs by document slug" do
    slug_match_document = create(:document, project:, title: "Operations Note", slug: "security-audit-log")
    slug_match_version = create(:document_version, document: slug_match_document, version_label: "v4.0.0")
    other_document = create(:document, project:, title: "Security Audit Log", slug: "different-slug")
    other_version = create(:document_version, document: other_document, version_label: "v5.0.0")

    create_access_log!(
      action_type: :view,
      target_type: "page",
      target_name: "slug-match.html",
      document: slug_match_document,
      document_version: slug_match_version
    )
    create_access_log!(
      action_type: :view,
      target_type: "page",
      target_name: "slug-miss.html",
      document: other_document,
      document_version: other_version
    )

    sign_in_as(admin_user)

    get admin_access_logs_path(document_q: "security-audit")

    expect(response).to have_http_status(:ok)
    expect(log_target_names).to eq(["slug-match.html"])
  end

  it "shows only the latest 200 access logs in recent order" do
    base_time = Time.zone.parse("2026-05-01 00:00:00 UTC")

    205.times do |index|
      create_access_log!(
        action_type: :view,
        target_type: "page",
        target_name: "entry-#{index}",
        accessed_at: base_time + index.seconds
      )
    end

    sign_in_as(admin_user)

    get admin_access_logs_path

    expect(response).to have_http_status(:ok)
    expect(log_target_names.size).to eq(200)
    expect(log_target_names.first).to eq("entry-204")
    expect(log_target_names.last).to eq("entry-5")
    expect(log_target_names).not_to include("entry-4", "entry-3", "entry-2", "entry-1", "entry-0")
  end

  it "forbids external users" do
    sign_in_as(external_user)

    get admin_access_logs_path

    expect(response).to have_http_status(:forbidden)
  end
end
