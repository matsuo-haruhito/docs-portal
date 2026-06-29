require "rails_helper"

RSpec.describe "Admin project membership remote search", type: :request do
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

  def project_field
    parsed_html.at_css('[name="project_membership[project_id]"]')
  end

  def user_field
    parsed_html.at_css('[name="project_membership[user_id]"]')
  end

  it "renders project and user fields as bounded remote comboboxes" do
    sign_in_as(admin_user)

    get admin_project_memberships_path

    expect(response).to have_http_status(:ok)
    expect(project_field).to be_present
    expect(project_field["data-rails-fields-kit--tom-select-url-value"]).to eq(project_search_admin_project_memberships_path(format: :json))
    expect(project_field["data-rails-fields-kit--tom-select-selected-url-value"]).to eq(selected_project_admin_project_memberships_path(format: :json))
    expect(project_field["data-rails-fields-kit--tom-select-value-field-value"]).to eq("value")
    expect(project_field["data-rails-fields-kit--tom-select-label-field-value"]).to eq("text")
    expect(project_field["data-rails-fields-kit--tom-select-max-options-value"]).to eq(Admin::ProjectMembershipsController::PROJECT_SEARCH_LIMIT.to_s)

    expect(user_field).to be_present
    expect(user_field["data-rails-fields-kit--tom-select-url-value"]).to eq(user_search_admin_project_memberships_path(format: :json))
    expect(user_field["data-rails-fields-kit--tom-select-selected-url-value"]).to eq(selected_user_admin_project_memberships_path(format: :json))
    expect(user_field["data-rails-fields-kit--tom-select-value-field-value"]).to eq("value")
    expect(user_field["data-rails-fields-kit--tom-select-label-field-value"]).to eq("text")
    expect(user_field["data-rails-fields-kit--tom-select-max-options-value"]).to eq(Admin::ProjectMembershipsController::USER_SEARCH_LIMIT.to_s)
  end

  it "returns project options by code and name while bounding query length and result count" do
    max_length = Admin::ProjectMembershipsController::PROJECT_SEARCH_QUERY_MAX_LENGTH
    bounded_query = "remote-" + ("a" * (max_length - "remote-".length))
    code_match = create(:project, code: "REMOTE-PROJECT", name: "Code Match")
    name_match = create(:project, code: "NAME-PROJECT", name: "Project #{bounded_query}")
    suffix_only = create(:project, code: "SUFFIX-PROJECT", name: "needle only")
    21.times do |index|
      create(:project, code: format("LIMIT-P%02d", index), name: "Limit Project #{index}")
    end

    sign_in_as(admin_user)

    get project_search_admin_project_memberships_path(format: :json), params: { q: "REMOTE-PROJECT" }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options")).to include(
      a_hash_including("value" => code_match.id, "text" => "#{code_match.code} / #{code_match.name}")
    )

    get project_search_admin_project_memberships_path(format: :json), params: { q: "  #{bounded_query} needle  " }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options")).to contain_exactly(
      a_hash_including("value" => name_match.id, "text" => "#{name_match.code} / #{name_match.name}")
    )
    expect(json_body.fetch("options")).not_to include(a_hash_including("value" => suffix_only.id))

    get project_search_admin_project_memberships_path(format: :json), params: { q: "LIMIT-P" }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options").size).to eq(Admin::ProjectMembershipsController::PROJECT_SEARCH_LIMIT)
    expect(json_body.fetch("options").map { |option| option.fetch("text") }).to all(start_with("LIMIT-P"))
  end

  it "returns user options by display name and email while bounding query length and result count" do
    max_length = Admin::ProjectMembershipsController::USER_SEARCH_QUERY_MAX_LENGTH
    bounded_query = "remote-" + ("a" * (max_length - "remote-".length))
    email_match = create(:user, :external, name: "Email Match", email_address: "remote-user@example.com")
    name_match = create(:user, :external, name: "User #{bounded_query}", email_address: "name-match@example.com")
    suffix_only = create(:user, :external, name: "needle only", email_address: "suffix@example.com")
    21.times do |index|
      create(:user, :external, name: "Limit User #{index}", email_address: format("limit-user-%02d@example.com", index))
    end

    sign_in_as(admin_user)

    get user_search_admin_project_memberships_path(format: :json), params: { q: "remote-user@example.com" }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options")).to include(
      a_hash_including("value" => email_match.id, "text" => "#{email_match.display_name} / #{email_match.email_address}")
    )

    get user_search_admin_project_memberships_path(format: :json), params: { q: "  #{bounded_query} needle  " }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options")).to contain_exactly(
      a_hash_including("value" => name_match.id, "text" => "#{name_match.display_name} / #{name_match.email_address}")
    )
    expect(json_body.fetch("options")).not_to include(a_hash_including("value" => suffix_only.id))

    get user_search_admin_project_memberships_path(format: :json), params: { q: "limit-user-" }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options").size).to eq(Admin::ProjectMembershipsController::USER_SEARCH_LIMIT)
    expect(json_body.fetch("options").map { |option| option.fetch("text") }).to all(include("limit-user-"))
  end

  it "restores selected project and user options on edit and invalid rerender" do
    project = create(:project, code: "SEL-PROJECT", name: "Selected Project")
    user = create(:user, :external, name: "Selected User", email_address: "selected-user@example.com")
    membership = create(:project_membership, project:, user:, role: :viewer)

    sign_in_as(admin_user)

    get selected_project_admin_project_memberships_path(format: :json), params: { id: project.id }
    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("option")).to include("value" => project.id, "text" => "SEL-PROJECT / Selected Project")

    get selected_user_admin_project_memberships_path(format: :json), params: { id: user.id }
    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("option")).to include("value" => user.id, "text" => "Selected User / selected-user@example.com")

    get edit_admin_project_membership_path(membership.public_id)
    expect(response).to have_http_status(:ok)
    expect(page_text).to include("SEL-PROJECT / Selected Project")
    expect(page_text).to include("Selected User / selected-user@example.com")

    post admin_project_memberships_path, params: {
      project_membership: {
        project_id: project.id,
        user_id: user.id,
        role: "editor"
      }
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(page_text).to include("SEL-PROJECT / Selected Project")
    expect(page_text).to include("Selected User / selected-user@example.com")
  end

  it "keeps project and user lookup endpoints inside the admin boundary" do
    project = create(:project, code: "ADMIN-PROJECT", name: "Admin Project")
    user = create(:user, :external, name: "Admin User", email_address: "admin-user@example.com")

    sign_in_as(external_user)

    get project_search_admin_project_memberships_path(format: :json), params: { q: project.code }
    expect(response).to have_http_status(:forbidden)

    get selected_project_admin_project_memberships_path(format: :json), params: { id: project.id }
    expect(response).to have_http_status(:forbidden)

    get user_search_admin_project_memberships_path(format: :json), params: { q: user.email_address }
    expect(response).to have_http_status(:forbidden)

    get selected_user_admin_project_memberships_path(format: :json), params: { id: user.id }
    expect(response).to have_http_status(:forbidden)
  end
end
