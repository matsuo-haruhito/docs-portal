require "rails_helper"

RSpec.describe "Admin nav active cue", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def nav_list
    parsed_html.at_css("ul.nav-list")
  end

  def nav_section(label)
    nav_list.css("li.nav-section").find { |section| section.text.squish == label }
  end

  def nav_link(label)
    nav_list.css("a[href]").find { |link| link.text.squish == label }
  end

  def expect_current_section(label)
    section = nav_section(label)

    expect(section).to be_present
    expect(section["aria-current"]).to eq("location")
    expect(section["aria-label"]).to eq("現在の領域: #{label}")
    expect(section["class"]).to include("border-primary")
    expect(section["class"]).to include("text-primary")
  end

  def expect_inactive_section(label)
    section = nav_section(label)

    expect(section).to be_present
    expect(section["aria-current"]).to be_nil
    expect(section["aria-label"]).to be_nil
  end

  def expect_current_link(label, path)
    link = nav_link(label)

    expect(link).to be_present
    expect(link["href"]).to eq(path)
    expect(link["aria-current"]).to eq("page")
    expect(link["class"]).to include("fw-bold")
  end

  it "marks the operations heading separately from the current dashboard link" do
    sign_in_as(admin_user)

    get admin_root_path

    expect(response).to have_http_status(:ok)
    expect_current_section("運用")
    expect_current_link("ダッシュボード", admin_root_path)
    expect_inactive_section("基本マスタ")
    expect_inactive_section("文書・権限")
    expect_inactive_section("import / sync")
    expect_inactive_section("外部連携")
  end

  it "marks a non-dashboard admin section without mixing heading and link current states" do
    sign_in_as(admin_user)

    get admin_projects_path

    expect(response).to have_http_status(:ok)
    expect_current_section("基本マスタ")
    expect_current_link("案件", admin_projects_path)
    expect_inactive_section("運用")
    expect_inactive_section("文書・権限")
    expect_inactive_section("import / sync")
    expect_inactive_section("外部連携")
  end

  it "keeps company master admin navigation limited to company and user links" do
    company = create(:company, name: "Alpha", domain: "alpha.example.com")
    sign_in_as(create(:user, :external, :company_master_admin, company:))

    get admin_root_path

    link_labels = nav_list.css("a[href]").map { |link| link.text.squish }
    link_targets = nav_list.css("a[href]").map { |link| link["href"] }

    expect(response).to have_http_status(:ok)
    expect(nav_list.css("li.nav-section")).to be_empty
    expect(link_labels).to contain_exactly("会社", "ユーザー")
    expect(link_targets).to contain_exactly(admin_companies_path, admin_users_path)
    expect(nav_list.css("[aria-current]")).to be_empty
    expect(nav_list.text.squish).not_to include("運用", "基本マスタ", "文書・権限", "import / sync", "外部連携")
  end
end
