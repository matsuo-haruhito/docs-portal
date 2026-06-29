require "rails_helper"

RSpec.describe "Admin document permission target remote search", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:external_user) { create(:user, :external) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def json_body
    JSON.parse(response.body)
  end

  def company_field
    parsed_html.at_css('[name="document_permission[company_id]"]')
  end

  def user_field
    parsed_html.at_css('[name="document_permission[user_id]"]')
  end

  def selected_company_option
    company_field.at_css("option[selected]")
  end

  def selected_user_option
    user_field.at_css("option[selected]")
  end

  it "renders company and user fields as bounded remote comboboxes" do
    sign_in_as(admin_user)

    get admin_document_permissions_path

    expect(response).to have_http_status(:ok)
    expect(company_field).to be_present
    expect(company_field["data-rails-fields-kit--tom-select-kind-value"]).to eq("combobox")
    expect(company_field["data-rails-fields-kit--tom-select-url-value"]).to eq(company_search_admin_document_permissions_path(format: :json))
    expect(company_field["data-rails-fields-kit--tom-select-selected-url-value"]).to eq(selected_company_admin_document_permissions_path(format: :json))
    expect(company_field["data-rails-fields-kit--tom-select-value-field-value"]).to eq("value")
    expect(company_field["data-rails-fields-kit--tom-select-label-field-value"]).to eq("text")
    expect(company_field["data-rails-fields-kit--tom-select-max-options-value"]).to eq(Admin::DocumentPermissionsController::COMPANY_SEARCH_LIMIT.to_s)
    expect(company_field.css("option")).to be_empty

    expect(user_field).to be_present
    expect(user_field["data-rails-fields-kit--tom-select-kind-value"]).to eq("combobox")
    expect(user_field["data-rails-fields-kit--tom-select-url-value"]).to eq(user_search_admin_document_permissions_path(format: :json))
    expect(user_field["data-rails-fields-kit--tom-select-selected-url-value"]).to eq(selected_user_admin_document_permissions_path(format: :json))
    expect(user_field["data-rails-fields-kit--tom-select-value-field-value"]).to eq("value")
    expect(user_field["data-rails-fields-kit--tom-select-label-field-value"]).to eq("text")
    expect(user_field["data-rails-fields-kit--tom-select-max-options-value"]).to eq(Admin::DocumentPermissionsController::USER_SEARCH_LIMIT.to_s)
    expect(user_field.css("option")).to be_empty
  end

  it "returns company options by domain and name while bounding query length and result count" do
    max_length = Admin::DocumentPermissionsController::COMPANY_SEARCH_QUERY_MAX_LENGTH
    bounded_query = "remote-" + ("a" * (max_length - "remote-".length))
    domain_match = create(:company, name: "Domain Match", domain: "remote-company.example")
    name_match = create(:company, name: "Company #{bounded_query}", domain: "name-match.example")
    suffix_only = create(:company, name: "needle only", domain: "suffix.example")
    21.times do |index|
      create(:company, name: "Limit Company #{index}", domain: format("limit-company-%02d.example", index))
    end

    sign_in_as(admin_user)

    get company_search_admin_document_permissions_path(format: :json), params: { q: "remote-company" }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options")).to include(
      a_hash_including("value" => domain_match.id, "text" => "Domain Match / remote-company.example")
    )

    get company_search_admin_document_permissions_path(format: :json), params: { q: "  #{bounded_query} needle  " }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options")).to contain_exactly(
      a_hash_including("value" => name_match.id, "text" => "Company #{bounded_query} / name-match.example")
    )
    expect(json_body.fetch("options")).not_to include(a_hash_including("value" => suffix_only.id))

    get company_search_admin_document_permissions_path(format: :json), params: { q: "limit-company-" }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options").size).to eq(Admin::DocumentPermissionsController::COMPANY_SEARCH_LIMIT)
    expect(json_body.fetch("options").map { |option| option.fetch("text") }).to all(include("limit-company-"))
  end

  it "returns user options by display name and email while bounding query length and result count" do
    max_length = Admin::DocumentPermissionsController::USER_SEARCH_QUERY_MAX_LENGTH
    bounded_query = "remote-" + ("a" * (max_length - "remote-".length))
    email_match = create(:user, :external, name: "Email Match", email_address: "remote-user@example.com")
    name_match = create(:user, :external, name: "User #{bounded_query}", email_address: "name-match@example.com")
    suffix_only = create(:user, :external, name: "needle only", email_address: "suffix@example.com")
    21.times do |index|
      create(:user, :external, name: "Limit User #{index}", email_address: format("limit-user-%02d@example.com", index))
    end

    sign_in_as(admin_user)

    get user_search_admin_document_permissions_path(format: :json), params: { q: "remote-user@example.com" }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options")).to include(
      a_hash_including("value" => email_match.id, "text" => "Email Match / remote-user@example.com")
    )

    get user_search_admin_document_permissions_path(format: :json), params: { q: "  #{bounded_query} needle  " }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options")).to contain_exactly(
      a_hash_including("value" => name_match.id, "text" => "User #{bounded_query} / name-match@example.com")
    )
    expect(json_body.fetch("options")).not_to include(a_hash_including("value" => suffix_only.id))

    get user_search_admin_document_permissions_path(format: :json), params: { q: "limit-user-" }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options").size).to eq(Admin::DocumentPermissionsController::USER_SEARCH_LIMIT)
    expect(json_body.fetch("options").map { |option| option.fetch("text") }).to all(include("limit-user-"))
  end

  it "restores selected company and user options on edit and invalid rerender" do
    document = create(:document, title: "Selected Permission Target")
    company = create(:company, name: "Selected Company", domain: "selected-company.example")
    user = create(:user, :external, name: "Selected User", email_address: "selected-user@example.com")
    company_permission = create(:document_permission, document:, company:, access_level: :view)
    user_permission = create(:document_permission, document:, user:, access_level: :download)

    sign_in_as(admin_user)

    get selected_company_admin_document_permissions_path(format: :json), params: { id: company.id }
    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("option")).to include("value" => company.id, "text" => "Selected Company / selected-company.example")

    get selected_company_admin_document_permissions_path(format: :json), params: { id: "999999" }
    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("option")).to be_nil

    get selected_user_admin_document_permissions_path(format: :json), params: { id: user.id }
    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("option")).to include("value" => user.id, "text" => "Selected User / selected-user@example.com")

    get selected_user_admin_document_permissions_path(format: :json), params: { id: "999999" }
    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("option")).to be_nil

    get edit_admin_document_permission_path(company_permission.public_id)
    expect(response).to have_http_status(:ok)
    expect(selected_company_option["value"]).to eq(company.id.to_s)
    expect(selected_company_option.text).to eq("Selected Company / selected-company.example")

    get edit_admin_document_permission_path(user_permission.public_id)
    expect(response).to have_http_status(:ok)
    expect(selected_user_option["value"]).to eq(user.id.to_s)
    expect(selected_user_option.text).to eq("Selected User / selected-user@example.com")

    post admin_document_permissions_path, params: {
      document_permission: {
        document_id: document.id,
        company_id: company.id,
        user_id: user.id,
        access_level: "view"
      }
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(page_text).to include("適用対象は会社かユーザーのどちらか一方だけを指定してください。")
    expect(page_text).to include("Selected Company / selected-company.example")
    expect(page_text).to include("Selected User / selected-user@example.com")
  end

  it "keeps company and user lookup endpoints inside the admin boundary" do
    company = create(:company, name: "Admin Company", domain: "admin-company.example")
    user = create(:user, :external, name: "Admin User", email_address: "admin-user@example.com")

    sign_in_as(external_user)

    get company_search_admin_document_permissions_path(format: :json), params: { q: company.domain }
    expect(response).to have_http_status(:forbidden)

    get selected_company_admin_document_permissions_path(format: :json), params: { id: company.id }
    expect(response).to have_http_status(:forbidden)

    get user_search_admin_document_permissions_path(format: :json), params: { q: user.email_address }
    expect(response).to have_http_status(:forbidden)

    get selected_user_admin_document_permissions_path(format: :json), params: { id: user.id }
    expect(response).to have_http_status(:forbidden)
  end
end
