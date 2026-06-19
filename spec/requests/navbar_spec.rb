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

  def active_nav_links
    parsed_html.css('header .nav-dropdown__menu a[aria-current="page"]')
  end

  def active_nav_summaries
    parsed_html.css("header .nav-dropdown__summary.is-active")
  end

  def active_nav_current_labels
    active_nav_summaries.css(".nav-dropdown__current-label").map { |label| label.text.squish }
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

  it "marks the current document menu item and parent dropdown" do
    sign_in_as(create(:user, :internal))

    get dashboard_path

    expect(response).to have_http_status(:ok)
    expect(active_nav_links.map { |link| [link.text.squish, link["href"]] }).to eq([["ダッシュボード 現在", dashboard_path]])
    expect(active_nav_summaries.map { |summary| summary.text.squish }).to eq(["文書 現在ダッシュボード"])
    expect(active_nav_current_labels).to eq(["ダッシュボード"])
  end

  it "marks an admin menu item without changing role-gated destinations" do
    sign_in_as(create(:user, :internal))

    get admin_documents_path

    expect(response).to have_http_status(:ok)
    expect(active_nav_links.map { |link| [link.text.squish, link["href"]] }).to eq([["文書 現在", admin_documents_path]])
    expect(active_nav_summaries.map { |summary| summary.text.squish }).to eq(["管理メニュー 現在文書"])
    expect(active_nav_current_labels).to eq(["文書"])
  end

  it "keeps the duplicated Git import history cue on the history dropdown only" do
    sign_in_as(create(:user, :internal))

    get admin_git_import_runs_path

    expect(response).to have_http_status(:ok)
    expect(active_nav_links.map { |link| [link.text.squish, link["href"]] }).to eq([["Git取込履歴 現在", admin_git_import_runs_path]])
    expect(parsed_html.css("header .nav-dropdown__menu a[href='#{admin_git_import_runs_path}']").size).to eq(2)
    expect(active_nav_summaries.map { |summary| summary.text.squish }).to eq(["履歴照会 現在Git取込履歴"])
    expect(active_nav_current_labels).to eq(["Git取込履歴"])
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
    expect(active_nav_links.map { |link| link["href"] }).to eq([dashboard_path])
    expect(active_nav_summaries.map { |summary| summary.text.squish }).to eq(["文書 現在ダッシュボード"])
    expect(active_nav_current_labels).to eq(["ダッシュボード"])
  end
end
