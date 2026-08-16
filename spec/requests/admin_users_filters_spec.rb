require "rails_helper"

RSpec.describe "Admin users filters", type: :request do
  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def result_table_text
    parsed_html.css("tbody").text.squish
  end

  def table_column_keys
    parsed_html.css("[data-rails-table-preferences-column-key]").map { |node| node["data-rails-table-preferences-column-key"] }.uniq
  end

  def keyword_input
    parsed_html.at_css('input[name="q"]')
  end

  def filter_chip_texts
    parsed_html.css(".admin-filter-chip").map { |node| node.text.squish }
  end

  def list_count
    parsed_html.at_css(".admin-list-meta__count")&.text&.squish
  end

  def toolbar_clear_link
    parsed_html.css(".admin-filter-toolbar__actions a").find { |link| link.text.squish == "条件をクリア" }
  end

  def empty_state_clear_link
    parsed_html.css("a").find { |link| link.text.squish == "条件をクリア" }
  end

  def link_href(text)
    parsed_html.css("a").find { |link| link.text.squish == text }&.[]("href")
  end

  let(:internal_user) { create(:user, :internal) }
  let!(:company) { create(:company, domain: "tenant.example.com", name: "Tenant") }
  let!(:other_company) { create(:company, domain: "other.example.com", name: "Other") }

  it "shows filter actions only while user filters are active" do
    create(:user, :external, company:, name: "Clear Target", email_address: "clear-target@example.com")
    sign_in_as(internal_user)

    get admin_users_path

    expect(response).to have_http_status(:ok)
    expect(parsed_html.at_css(".admin-filter-toolbar")).to be_present
    expect(keyword_input).to be_present
    expect(keyword_input["placeholder"]).to eq("ユーザー名・メールアドレス")
    expect(keyword_input["maxlength"]).to eq("100")
    expect(parsed_html.at_css('select[name="active"]')).to be_present
    expect(filter_chip_texts).to be_empty
    expect(toolbar_clear_link).to be_nil

    get admin_users_path, params: { q: "clear target" }

    expect(response).to have_http_status(:ok)
    expect(filter_chip_texts).to eq(["キーワード「clear target」"])
    expect(list_count).to eq("1件")
    expect(toolbar_clear_link&.[]("href")).to eq(admin_users_path)
  end

  it "allows internal admins to search users across companies without changing table preferences" do
    create(:user, :external, company:, name: "Alpha Member", email_address: "alpha-member@example.com")
    create(:user, :external, company: other_company, name: "Omega Member", email_address: "omega-member@example.com")

    sign_in_as(internal_user)

    get admin_users_path, params: { q: "alpha" }

    expect(response).to have_http_status(:ok)
    expect(result_table_text).to include("alpha-member@example.com")
    expect(result_table_text).not_to include("omega-member@example.com")
    expect(filter_chip_texts).to eq(["キーワード「alpha」"])
    expect(list_count).to eq("1件")
    expect(table_column_keys).to include(
      "name",
      "email_address",
      "display_name",
      "user_type",
      "company",
      "status",
      "actions"
    )

    get admin_users_path, params: { q: "omega-member@example.com" }

    expect(response).to have_http_status(:ok)
    expect(result_table_text).to include("omega-member@example.com")
    expect(result_table_text).not_to include("alpha-member@example.com")
  end

  it "filters users by active status and distinguishes filtered empty results" do
    active_user = create(:user, :external, company:, name: "Enabled Match Target", email_address: "enabled-target@example.com", active: true)
    inactive_user = create(:user, :external, company:, name: "Disabled Match Target", email_address: "disabled-target@example.com", active: false)

    sign_in_as(internal_user)

    get admin_users_path, params: { q: "match target", active: "false" }

    expect(response).to have_http_status(:ok)
    expect(result_table_text).to include(inactive_user.email_address)
    expect(result_table_text).not_to include(active_user.email_address)
    expect(filter_chip_texts).to contain_exactly("キーワード「match target」", "状態: 無効")
    expect(list_count).to eq("1件")

    get admin_users_path, params: { q: "missing-user" }

    expect(response).to have_http_status(:ok)
    expect(filter_chip_texts).to eq(["キーワード「missing-user」"])
    expect(list_count).to eq("0件")
    expect(parsed_html.at_css(".empty-state")).to be_present
    expect(empty_state_clear_link&.[]("href")).to eq(admin_users_path)
    expect(parsed_html.at_css('[data-rails-table-preferences-table-key-value="admin_users"]')).to be_nil
  end

  it "keeps company_master_admin search and active filter inside the same company" do
    manager = create(:user, :external, :company_master_admin, company:, email_address: "manager@example.com")
    active_same_company_user = create(:user, :external, company:, name: "Shared Keyword", email_address: "same-active@example.com", active: true)
    create(:user, :external, company:, name: "Shared Keyword", email_address: "same-inactive@example.com", active: false)
    create(:user, :external, company: other_company, name: "Shared Keyword", email_address: "other-active@example.com", active: true)

    sign_in_as(manager)

    get admin_users_path, params: { q: "shared", active: "true" }

    expect(response).to have_http_status(:ok)
    expect(result_table_text).to include(active_same_company_user.email_address)
    expect(result_table_text).not_to include("same-inactive@example.com", "other-active@example.com")
    expect(filter_chip_texts).to contain_exactly("キーワード「shared」", "状態: 有効")

    get admin_users_path, params: { q: "other-active@example.com" }

    expect(response).to have_http_status(:ok)
    expect(list_count).to eq("0件")
    expect(result_table_text).not_to include("other-active@example.com")
  end

  it "paginates company_master_admin users without leaving the same-company scope" do
    manager = create(:user, :external, :company_master_admin, company:, email_address: "manager-page@example.com")
    same_company_users = Array.new(3) do |index|
      create(
        :user,
        :external,
        company:,
        name: "Shared Page",
        email_address: "shared-page-#{index}@example.com",
        active: true
      )
    end
    create(:user, :external, company: other_company, name: "Shared Page", email_address: "shared-page-other@example.com", active: true)

    sign_in_as(manager)

    get admin_users_path, params: { q: "shared page", active: "true", per_page: 2 }

    expect(response).to have_http_status(:ok)
    expect(list_count).to eq("3件")
    expect(parsed_html.at_css('nav[aria-label="ユーザー一覧ページ"]')).to be_present
    expect(result_table_text).to include(same_company_users.first.email_address, same_company_users.second.email_address)
    expect(result_table_text).not_to include(same_company_users.third.email_address, "shared-page-other@example.com")
    expect(link_href("次へ")).to include("q=shared+page", "active=true", "per_page=2", "page=2")

    get admin_users_path, params: { q: "shared page", active: "true", per_page: 2, page: 2 }

    expect(response).to have_http_status(:ok)
    expect(list_count).to eq("3件")
    expect(result_table_text).to include(same_company_users.third.email_address)
    expect(result_table_text).not_to include(same_company_users.first.email_address, "shared-page-other@example.com")
    expect(link_href("前へ")).to include("q=shared+page", "active=true", "per_page=2", "page=1")

    get admin_users_path, params: { q: "shared page", active: "true", per_page: 2, page: 0 }

    expect(response).to have_http_status(:ok)
    expect(result_table_text).to include(same_company_users.first.email_address)
  end
end
