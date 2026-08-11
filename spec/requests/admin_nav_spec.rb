require "rails_helper"

RSpec.describe "Admin navigation", type: :request do
  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def active_header_summary
    parsed_html.at_css("header .nav-dropdown__summary.is-active")
  end

  def active_header_link
    parsed_html.at_css("header .nav-dropdown__menu a[aria-current='page']")
  end

  def context_nav
    parsed_html.at_css("nav.admin-context-nav")
  end

  def expect_active_header_nav(menu_label:, link_label:, path:)
    expect(response).to have_http_status(:ok)
    expect(active_header_summary).to be_present
    expect(active_header_summary.text.squish).to start_with(menu_label)
    expect(active_header_summary.at_css(".nav-dropdown__current-label").text.squish).to eq(link_label)
    expect(active_header_link.text.squish).to eq("#{link_label} 現在")
    expect(active_header_link["href"]).to eq(path)
  end

  it "marks the current management menu on the admin dashboard" do
    sign_in_as(create(:user, :internal))

    get admin_root_path

    expect_active_header_nav(menu_label: "管理メニュー", link_label: "管理画面", path: admin_root_path)
  end

  it "marks the current master management link without changing link text" do
    sign_in_as(create(:user, :internal))

    get admin_companies_path

    expect_active_header_nav(menu_label: "管理メニュー", link_label: "会社", path: admin_companies_path)
  end

  it "marks the current document management link" do
    sign_in_as(create(:user, :internal))

    get admin_documents_path

    expect_active_header_nav(menu_label: "管理メニュー", link_label: "文書", path: admin_documents_path)
  end

  it "marks the current import and sync link" do
    sign_in_as(create(:user, :internal))

    get admin_git_import_sources_path

    expect_active_header_nav(menu_label: "連携メニュー", link_label: "Git取込元", path: admin_git_import_sources_path)
  end

  it "marks the current external integration link" do
    sign_in_as(create(:user, :internal))

    get admin_webhook_endpoints_path

    expect_active_header_nav(menu_label: "連携メニュー", link_label: "Webhook設定", path: admin_webhook_endpoints_path)
  end

  it "shows company master admin landing as a company and user management entrypoint" do
    sign_in_as(create(:user, :company_master_admin))

    get admin_root_path

    expect(response).to have_http_status(:ok)
    expect(context_nav["aria-label"]).to eq("会社・ユーザー管理")
    expect(context_nav.css("a").map { |link| link.text.squish }).to eq(["会社", "ユーザー"])
    expect(context_nav.css("a").map { |link| link["href"] }).to eq([admin_companies_path, admin_users_path])
    expect(context_nav.css("a[aria-current='page']")).to be_empty
    expect(page_text).to include("会社・ユーザー管理専用の入口")
    expect(page_text).to include("会社を管理")
    expect(page_text).to include("ユーザーを管理")
    expect(page_text).to include("internal admin へ戻す範囲")
    expect(page_text).to include("案件・案件所属")
    expect(page_text).to include("文書・文書権限")
    expect(page_text).to include("監査ログ、利用状況、アクセス申請")
  end

  it "marks company master admin company navigation without exposing internal links" do
    sign_in_as(create(:user, :company_master_admin))

    get admin_companies_path

    expect(response).to have_http_status(:ok)
    expect(context_nav.at_css("a[aria-current='page']").text.squish).to eq("会社")
    expect(context_nav.css("a").map { |link| link.text.squish }).to eq(["会社", "ユーザー"])
    expect(context_nav.text.squish).not_to include("監査ログ", "文書", "運用")
  end

  it "marks company master admin user navigation without adding wider admin surfaces" do
    sign_in_as(create(:user, :company_master_admin))

    get admin_users_path

    expect(response).to have_http_status(:ok)
    expect(context_nav.at_css("a[aria-current='page']").text.squish).to eq("ユーザー")
    expect(context_nav.css("a").map { |link| link["href"] }).to eq([admin_companies_path, admin_users_path])
  end
end
