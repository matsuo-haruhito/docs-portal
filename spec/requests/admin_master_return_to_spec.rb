require "rails_helper"

RSpec.describe "Admin master return_to", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def row_for(column_key, text)
    parsed_html.css("table tbody tr").find do |row|
      row.at_css(%(td[data-rails-table-preferences-column-key="#{column_key}"]))&.text&.squish == text
    end
  end

  def action_cell_for(column_key, text)
    row_for(column_key, text)&.at_css(%(td[data-rails-table-preferences-column-key="actions"]))
  end

  def action_link_for(column_key, text, label)
    action_cell_for(column_key, text)&.css("a[href]")&.find { |node| node.text.squish == label }
  end

  def action_form_for(column_key, text, path)
    action_cell_for(column_key, text)&.css("form[action]")&.find do |node|
      URI.parse(node["action"]).path == path
    end
  end

  def query_params(url)
    Rack::Utils.parse_nested_query(URI.parse(url).query)
  end

  def hidden_field_value(name)
    parsed_html.at_css(%(input[name="#{name}"]))&.[]("value")
  end

  def return_to_query(return_to)
    Rack::Utils.parse_nested_query(URI.parse(return_to).query)
  end

  def expect_admin_company_return_to(return_to)
    expect(URI.parse(return_to).path).to eq(admin_companies_path)
    expect(return_to_query(return_to)).to include(
      "q" => "alpha",
      "active" => "true",
      "page" => "2",
      "per_page" => "10"
    )
  end

  def expect_admin_user_return_to(return_to)
    expect(URI.parse(return_to).path).to eq(admin_users_path)
    expect(return_to_query(return_to)).to include(
      "q" => "member",
      "active" => "true",
      "page" => "2",
      "per_page" => "10"
    )
  end

  def company_update_params(company, name: company.name)
    {
      company: {
        domain: company.domain,
        name: name,
        active: company.active
      }
    }
  end

  def user_update_params(user, name: user.name)
    {
      user: {
        name: name,
        email_address: user.email_address,
        user_type: user.user_type,
        company_id: user.company_id,
        active: user.active
      }
    }
  end

  before do
    sign_in_as(admin_user)
  end

  it "keeps filtered company list context through edit, update, and destroy" do
    company = create(:company, domain: "alpha.example.com", name: "Alpha", active: true)
    create(:company, domain: "beta.example.com", name: "Beta", active: false)
    deletable_company = create(:company, domain: "alpha-delete.example.com", name: "Alpha Delete", active: true)

    get admin_companies_path, params: { q: "alpha", active: "true", page: 2, per_page: 10 }

    expect(response).to have_http_status(:ok)
    edit_return_to = query_params(action_link_for("domain", "alpha.example.com", "編集")["href"]).fetch("return_to")
    delete_return_to = query_params(action_form_for("domain", "alpha-delete.example.com", admin_company_path(deletable_company.public_id))["action"]).fetch("return_to")
    expect_admin_company_return_to(edit_return_to)
    expect_admin_company_return_to(delete_return_to)

    get edit_admin_company_path(company.public_id), params: { return_to: edit_return_to }

    expect(response).to have_http_status(:ok)
    expect(hidden_field_value("return_to")).to eq(edit_return_to)
    expect(parsed_html.css("a[href]").find { |node| node.text.squish == "一覧へ戻る" }["href"]).to eq(edit_return_to)

    patch admin_company_path(company.public_id), params: company_update_params(company, name: "Alpha Updated").merge(return_to: edit_return_to)

    expect(response).to redirect_to(edit_return_to)
    expect(company.reload.name).to eq("Alpha Updated")

    expect do
      delete admin_company_path(deletable_company.public_id), params: { return_to: delete_return_to }
    end.to change(Company, :count).by(-1)

    expect(response).to redirect_to(delete_return_to)
  end

  it "keeps filtered user list context through edit, update, and destroy" do
    company = create(:company, domain: "tenant.example.com", name: "Tenant")
    user = create(:user, :external, company:, name: "Member", email_address: "member@example.com", active: true)
    create(:user, :external, company:, name: "Inactive", email_address: "inactive@example.com", active: false)
    deletable_user = create(:user, :external, company:, name: "Member Delete", email_address: "member-delete@example.com", active: true)

    get admin_users_path, params: { q: "member", active: "true", page: 2, per_page: 10 }

    expect(response).to have_http_status(:ok)
    edit_return_to = query_params(action_link_for("email_address", "member@example.com", "編集")["href"]).fetch("return_to")
    delete_return_to = query_params(action_form_for("email_address", "member-delete@example.com", admin_user_path(deletable_user.public_id))["action"]).fetch("return_to")
    expect_admin_user_return_to(edit_return_to)
    expect_admin_user_return_to(delete_return_to)

    get edit_admin_user_path(user.public_id), params: { return_to: edit_return_to }

    expect(response).to have_http_status(:ok)
    expect(hidden_field_value("return_to")).to eq(edit_return_to)
    expect(parsed_html.css("a[href]").find { |node| node.text.squish == "一覧へ戻る" }["href"]).to eq(edit_return_to)

    patch admin_user_path(user.public_id), params: user_update_params(user, name: "Member Updated").merge(return_to: edit_return_to)

    expect(response).to redirect_to(edit_return_to)
    expect(user.reload.name).to eq("Member Updated")

    expect do
      delete admin_user_path(deletable_user.public_id), params: { return_to: delete_return_to }
    end.to change(User, :count).by(-1)

    expect(response).to redirect_to(delete_return_to)
  end

  it "falls back for unsafe company and user return_to values" do
    company = create(:company, domain: "unsafe.example.com", name: "Unsafe", active: true)
    user = create(:user, :external, company:, name: "Unsafe User", email_address: "unsafe-user@example.com", active: true)
    unsafe_return_to_values = [
      nil,
      "",
      "//evil.example/admin",
      "https://evil.example/admin",
      "javascript:alert(1)",
      "#fragment",
      "/admin/companies\nX-Injected: yes"
    ]

    unsafe_return_to_values.each_with_index do |return_to, index|
      company_params = company_update_params(company, name: "Unsafe Company #{index}")
      company_params[:return_to] = return_to unless return_to.nil?

      patch admin_company_path(company.public_id), params: company_params

      expect(response).to redirect_to(admin_companies_path)

      user_params = user_update_params(user, name: "Unsafe User #{index}")
      user_params[:return_to] = return_to unless return_to.nil?

      patch admin_user_path(user.public_id), params: user_params

      expect(response).to redirect_to(admin_users_path)
    end
  end

  it "does not widen company_master_admin scope when return_to is present" do
    company = create(:company, domain: "tenant.example.com", name: "Tenant")
    other_company = create(:company, domain: "other.example.com", name: "Other")
    manager = create(:user, :external, :company_master_admin, company:, email_address: "manager-return@example.com")
    other_user = create(:user, :external, company: other_company, email_address: "other-return@example.com")

    sign_in_as(manager)

    patch admin_company_path(other_company.public_id), params: company_update_params(other_company, name: "Other Updated").merge(return_to: admin_companies_path(q: "tenant"))

    expect(response).to have_http_status(:not_found)
    expect(other_company.reload.name).to eq("Other")

    patch admin_user_path(other_user.public_id), params: user_update_params(other_user, name: "Other Updated").merge(return_to: admin_users_path(q: "tenant"))

    expect(response).to have_http_status(:not_found)
    expect(other_user.reload.name).not_to eq("Other Updated")
  end
end
