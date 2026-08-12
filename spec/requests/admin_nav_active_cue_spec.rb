require "rails_helper"

RSpec.describe "Admin nav active cue", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def active_summary
    parsed_html.at_css("header .nav-dropdown__summary.is-active")
  end

  def active_link
    parsed_html.at_css("header .nav-dropdown__menu a[aria-current='page']")
  end

  def expect_current_header_link(label, path, menu_label)
    expect(active_summary).to be_present
    expect(active_summary.text.squish).to start_with(menu_label)
    expect(active_summary.at_css(".nav-dropdown__current-label").text.squish).to eq(label)
    expect(active_link).to be_present
    expect(active_link["href"]).to eq(path)
    expect(active_link.text.squish).to eq("#{label} 現在")
    expect(active_link["class"]).to include("is-active")
  end

  it "marks the management dropdown and dashboard link" do
    sign_in_as(admin_user)

    get admin_root_path

    expect(response).to have_http_status(:ok)
    expect_current_header_link("管理画面", admin_root_path, "管理メニュー")
  end

  it "marks a non-dashboard admin link without activating another dropdown" do
    sign_in_as(admin_user)

    get admin_projects_path

    expect(response).to have_http_status(:ok)
    expect_current_header_link("案件", admin_projects_path, "管理メニュー")
    expect(parsed_html.css("header .nav-dropdown__summary.is-active").size).to eq(1)
  end

  it "keeps company master admin context navigation limited to company and user links" do
    company = create(:company, name: "Alpha", domain: "alpha.example.com")
    sign_in_as(create(:user, :external, :company_master_admin, company:))

    get admin_root_path

    context_nav = parsed_html.at_css("nav.admin-context-nav")
    link_labels = context_nav.css("a[href]").map { |link| link.text.squish }
    link_targets = context_nav.css("a[href]").map { |link| link["href"] }

    expect(response).to have_http_status(:ok)
    expect(context_nav["aria-label"]).to eq("会社・ユーザー管理")
    expect(link_labels).to contain_exactly("会社", "ユーザー")
    expect(link_targets).to contain_exactly(admin_companies_path, admin_users_path)
    expect(context_nav.css("a[aria-current]")).to be_empty
    expect(parsed_html.css("header .nav-dropdown__summary").map { |node| node.text.squish }).not_to include("管理メニュー", "連携メニュー")
  end
end
