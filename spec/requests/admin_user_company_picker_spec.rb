require "rails_helper"

RSpec.describe "Admin user company picker", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:external_user) { create(:user, :external) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def json_body
    JSON.parse(response.body)
  end

  def company_picker
    parsed_html.at_css('select[name="user[company_id]"]')
  end

  it "returns bounded company search results by name and domain for internal admins" do
    name_match = create(:company, domain: "alpha.example.com", name: "Alpha Company")
    domain_match = create(:company, domain: "needle.example.com", name: "Domain Match")

    max_length = Admin::UsersController::COMPANY_SEARCH_QUERY_MAX_LENGTH
    bounded_query = "remote-" + ("a" * (max_length - "remote-".length))
    bounded_match = create(:company, domain: "bounded.example.com", name: "Target #{bounded_query}")
    suffix_only = create(:company, domain: "suffix.example.com", name: "Suffix only source")
    21.times do |index|
      create(:company, domain: format("limit-%02d.example.com", index), name: format("Limit Company %02d", index))
    end

    sign_in_as(admin_user)

    get company_search_admin_users_path, params: { q: "alpha" }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options")).to contain_exactly(
      a_hash_including("value" => name_match.id, "text" => "Alpha Company / alpha.example.com")
    )

    get company_search_admin_users_path, params: { q: "needle" }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options")).to contain_exactly(
      a_hash_including("value" => domain_match.id, "text" => "Domain Match / needle.example.com")
    )

    get company_search_admin_users_path, params: { q: "  #{bounded_query}   suffix  " }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options")).to contain_exactly(
      a_hash_including("value" => bounded_match.id, "text" => "Target #{bounded_query} / bounded.example.com")
    )
    expect(json_body.fetch("options")).not_to include(a_hash_including("value" => suffix_only.id))

    get company_search_admin_users_path, params: { q: "limit" }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options").size).to eq(Admin::UsersController::COMPANY_SEARCH_LIMIT)
    expect(json_body.fetch("options").map { |option| option.fetch("text") }).to all(include("Limit Company"))
  end

  it "returns selected company options for edit and validation rerender restoration" do
    company = create(:company, domain: "restore.example.com", name: "Restore Company")

    sign_in_as(admin_user)

    get selected_company_admin_users_path, params: { id: company.id }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("option")).to include(
      "value" => company.id,
      "text" => "Restore Company / restore.example.com"
    )

    get selected_company_admin_users_path, params: { id: "missing" }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("option")).to be_nil
  end

  it "renders the remote company combobox and restores selected companies on invalid create and edit" do
    company = create(:company, domain: "form.example.com", name: "Form Company")
    user = create(:user, :external, company:, email_address: "member-form@example.com")

    sign_in_as(admin_user)

    get admin_users_path

    expect(response).to have_http_status(:ok)
    picker = company_picker
    expect(picker).to be_present
    expect(picker["data-controller"]).to include("rails-fields-kit--tom-select")
    expect(picker["data-rails-fields-kit--tom-select-kind-value"]).to eq("combobox")
    expect(picker["data-rails-fields-kit--tom-select-url-value"]).to eq(company_search_admin_users_path(format: :json))
    expect(picker["data-rails-fields-kit--tom-select-selected-url-value"]).to eq(selected_company_admin_users_path(format: :json))
    expect(picker["data-rails-fields-kit--tom-select-value-field-value"]).to eq("value")
    expect(picker["data-rails-fields-kit--tom-select-label-field-value"]).to eq("text")
    expect(picker["data-rails-fields-kit--tom-select-search-field-value"]).to eq("text")
    expect(picker["data-rails-fields-kit--tom-select-min-length-value"]).to eq("1")
    expect(picker["data-rails-fields-kit--tom-select-max-options-value"]).to eq("20")

    post admin_users_path, params: {
      user: {
        name: "Invalid Member",
        email_address: "",
        user_type: "external",
        company_id: company.id,
        active: "true",
        password: "password123!",
        password_confirmation: "password123!"
      }
    }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(company_picker.at_css(%(option[value="#{company.id}"][selected]))&.text&.squish).to eq("Form Company / form.example.com")

    get edit_admin_user_path(user.public_id)

    expect(response).to have_http_status(:ok)
    expect(company_picker.at_css(%(option[value="#{company.id}"][selected]))&.text&.squish).to eq("Form Company / form.example.com")
  end

  it "keeps company_master_admin users fixed to their own company" do
    company = create(:company, domain: "tenant.example.com", name: "Tenant")
    other_company = create(:company, domain: "other.example.com", name: "Other")
    manager = create(:user, :external, :company_master_admin, company:, email_address: "manager-picker@example.com")

    sign_in_as(manager)

    get admin_users_path

    expect(response).to have_http_status(:ok)
    expect(company_picker).to be_nil
    expect(parsed_html.at_css('input[name="user[company_id]"][type="hidden"]')["value"]).to eq(company.id.to_s)
    expect(response.body).to include("この会社で固定され、会社欄は変更できません。")

    get company_search_admin_users_path, params: { q: "tenant" }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options")).to contain_exactly(
      a_hash_including("value" => company.id, "text" => "Tenant / tenant.example.com")
    )

    get selected_company_admin_users_path, params: { id: other_company.id }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("option")).to be_nil
  end

  it "forbids external users from company picker JSON endpoints" do
    company = create(:company)

    sign_in_as(external_user)

    get company_search_admin_users_path, params: { q: company.domain }

    expect(response).to have_http_status(:forbidden)

    get selected_company_admin_users_path, params: { id: company.id }

    expect(response).to have_http_status(:forbidden)
  end
end
