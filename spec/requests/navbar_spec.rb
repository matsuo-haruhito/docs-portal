require "rails_helper"

RSpec.describe "Navbar", type: :request do
  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def navbar_hrefs
    parsed_html.css("header .nav-dropdown__menu a").map { |link| link["href"] }
  end

  def navbar_section_labels
    parsed_html.css("header .nav-dropdown__section-label").map { |label| label.text.squish }
  end

  it "groups admin navbar links without changing their destinations" do
    sign_in_as(create(:user, :internal))

    get dashboard_path

    expect(response).to have_http_status(:ok)
    expect(navbar_section_labels).to include(
      "日常利用",
      "社内確認",
      "利用者履歴",
      "監査・管理履歴",
      "管理ホーム",
      "マスタ管理",
      "文書管理",
      "診断",
      "仕様確認",
      "取込・同期",
      "通知連携"
    )
    expect(navbar_hrefs).to include(
      dashboard_path,
      projects_path,
      document_bookmarks_path,
      access_requests_path,
      document_approval_requests_path,
      document_delivery_logs_path,
      consents_path,
      admin_root_path,
      admin_companies_path,
      admin_users_path,
      admin_projects_path,
      admin_project_memberships_path,
      admin_consent_terms_path,
      admin_project_consent_settings_path,
      admin_documents_path,
      admin_document_sets_path,
      admin_document_permissions_path,
      admin_access_requests_path,
      new_admin_bulk_edit_dry_run_path,
      admin_model_browser_path,
      admin_api_specification_path,
      admin_git_import_sources_path,
      admin_git_import_runs_path,
      admin_microsoft_graph_connections_path,
      admin_external_folder_sync_sources_path,
      admin_webhook_endpoints_path,
      admin_access_logs_path,
      admin_document_usage_reports_path
    )
  end

  it "keeps external users out of internal and admin navbar links" do
    sign_in_as(create(:user, :external))

    get dashboard_path

    expect(response).to have_http_status(:ok)
    expect(navbar_section_labels).to include("日常利用", "利用者履歴")
    expect(navbar_section_labels).not_to include(
      "社内確認",
      "監査・管理履歴",
      "管理ホーム",
      "マスタ管理",
      "文書管理",
      "診断",
      "仕様確認",
      "取込・同期",
      "通知連携"
    )
    expect(navbar_hrefs).to include(
      dashboard_path,
      projects_path,
      document_bookmarks_path,
      access_requests_path,
      document_delivery_logs_path,
      consents_path
    )
    expect(navbar_hrefs).not_to include(
      document_approval_requests_path,
      admin_root_path,
      admin_companies_path,
      admin_users_path,
      admin_projects_path,
      admin_project_memberships_path,
      admin_documents_path,
      admin_document_permissions_path,
      admin_access_logs_path,
      admin_document_usage_reports_path,
      admin_git_import_sources_path,
      admin_webhook_endpoints_path
    )
  end
end
