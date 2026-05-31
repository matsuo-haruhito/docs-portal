require "rails_helper"

RSpec.describe "Admin users filters", type: :request do
  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def table_column_keys
    parsed_html.css("[data-rails-table-preferences-column-key]").map { |node| node["data-rails-table-preferences-column-key"] }.uniq
  end

  let(:internal_user) { create(:user, :internal) }
  let!(:company) { create(:company, domain: "tenant.example.com", name: "Tenant") }
  let!(:other_company) { create(:company, domain: "other.example.com", name: "Other") }

  it "allows internal admins to search users across companies without changing table preferences" do
    create(:user, :external, company:, name: "Alpha Member", email_address: "alpha-member@example.com")
    create(:user, :external, company: other_company, name: "Omega Member", email_address: "omega-member@example.com")

    sign_in_as(internal_user)

    get admin_users_path, params: { q: "alpha" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("alpha-member@example.com")
    expect(page_text).not_to include("omega-member@example.com")
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
    expect(page_text).to include("omega-member@example.com")
    expect(page_text).not_to include("alpha-member@example.com")
  end

  it "filters users by active status and distinguishes filtered empty results" do
    active_user = create(:user, :external, company:, name: "Enabled Match Target", email_address: "enabled-target@example.com", active: true)
    inactive_user = create(:user, :external, company:, name: "Disabled Match Target", email_address: "disabled-target@example.com", active: false)

    sign_in_as(internal_user)

    get admin_users_path, params: { q: "match target", active: "false" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include(inactive_user.email_address)
    expect(page_text).not_to include(active_user.email_address)

    get admin_users_path, params: { q: "missing-user" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("検索条件に一致するユーザーはありません。")
    expect(page_text).to include("キーワードや状態の条件を変更するか、条件をクリアしてください。")
    expect(page_text).not_to include("まだ表示中の範囲にユーザーは登録されていません。")
  end

  it "keeps company_master_admin search and active filter inside the same company" do
    manager = create(:user, :external, :company_master_admin, company:, email_address: "manager@example.com")
    active_same_company_user = create(:user, :external, company:, name: "Shared Keyword", email_address: "same-active@example.com", active: true)
    create(:user, :external, company:, name: "Shared Keyword", email_address: "same-inactive@example.com", active: false)
    create(:user, :external, company: other_company, name: "Shared Keyword", email_address: "other-active@example.com", active: true)

    sign_in_as(manager)

    get admin_users_path, params: { q: "shared", active: "true" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include(active_same_company_user.email_address)
    expect(page_text).not_to include("same-inactive@example.com")
    expect(page_text).not_to include("other-active@example.com")

    get admin_users_path, params: { q: "other-active@example.com" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("検索条件に一致するユーザーはありません。")
    expect(page_text).not_to include("other-active@example.com")
  end
end
