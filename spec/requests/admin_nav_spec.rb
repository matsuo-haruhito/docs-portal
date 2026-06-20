require "rails_helper"

RSpec.describe "Admin navigation", type: :request do
  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def active_nav_section
    parsed_html.at_css(".nav-list .nav-section[aria-current='location']")
  end

  def active_nav_section_label
    active_nav_section&.text&.squish
  end

  def active_nav_link
    parsed_html.at_css(".nav-list a[aria-current='page']")
  end

  def expect_active_nav(section_label:, link_label:)
    expect(response).to have_http_status(:ok)
    expect(active_nav_section_label).to eq("#{section_label} 現在")
    expect(active_nav_section["aria-label"]).to eq("現在の領域: #{section_label}")
    expect(active_nav_link.text.squish).to eq(link_label)
  end

  it "marks the current operations section on the admin dashboard" do
    sign_in_as(create(:user, :internal))

    get admin_root_path

    expect_active_nav(section_label: "運用", link_label: "ダッシュボード")
  end

  it "marks the current basic master section without changing link text" do
    sign_in_as(create(:user, :internal))

    get admin_companies_path

    expect_active_nav(section_label: "基本マスタ", link_label: "会社")
  end

  it "marks the current document permission section" do
    sign_in_as(create(:user, :internal))

    get admin_documents_path

    expect_active_nav(section_label: "文書・権限", link_label: "文書")
  end

  it "marks the current import and sync section" do
    sign_in_as(create(:user, :internal))

    get admin_git_import_sources_path

    expect_active_nav(section_label: "import / sync", link_label: "Git連携")
  end

  it "marks the current external integration section" do
    sign_in_as(create(:user, :internal))

    get admin_webhook_endpoints_path

    expect_active_nav(section_label: "外部連携", link_label: "Webhook")
  end

  it "keeps company master admin navigation free of internal section cues" do
    sign_in_as(create(:user, :company_master_admin))

    get admin_companies_path

    expect(response).to have_http_status(:ok)
    expect(parsed_html.css(".nav-list .nav-section")).to be_empty
    expect(parsed_html.css(".nav-list a").map { |link| link.text.squish }).to eq(["会社", "ユーザー"])
    expect(parsed_html.at_css(".nav-list [aria-current='location']")).to be_nil
  end
end
