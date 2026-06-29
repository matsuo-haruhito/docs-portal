require "rails_helper"

RSpec.describe "Admin document permission project filter search", type: :request do
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

  def project_filter_field
    parsed_html.at_css('[name="project_id"]')
  end

  def selected_project_option
    project_filter_field.at_css("option[selected]")
  end

  it "returns bounded project options by code and name" do
    code_match = create(:project, code: "FILTER-CODE", name: "Code Match Project")
    name_match = create(:project, code: "NAME-ONLY", name: "Remote Filter Project")
    suffix_only = create(:project, code: "SUFFIX", name: "needle only")
    21.times do |index|
      create(:project, code: format("LIMIT-%02d", index), name: "Limit Project #{index}")
    end

    sign_in_as(admin_user)

    get project_search_admin_document_permissions_path(format: :json), params: { q: "filter-code" }
    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options")).to include(
      a_hash_including("value" => code_match.id, "text" => "FILTER-CODE / Code Match Project")
    )

    max_length = Admin::DocumentPermissionsController::PROJECT_SEARCH_QUERY_MAX_LENGTH
    bounded_query = "remote-" + ("a" * (max_length - "remote-".length))
    name_match.update!(name: "Project #{bounded_query}")

    get project_search_admin_document_permissions_path(format: :json), params: { q: "  #{bounded_query} needle  " }
    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options")).to contain_exactly(
      a_hash_including("value" => name_match.id, "text" => "NAME-ONLY / Project #{bounded_query}")
    )
    expect(json_body.fetch("options")).not_to include(a_hash_including("value" => suffix_only.id))

    get project_search_admin_document_permissions_path(format: :json), params: { q: "limit-" }
    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options").size).to eq(Admin::DocumentPermissionsController::PROJECT_SEARCH_LIMIT)
    expect(json_body.fetch("options").map { |option| option.fetch("text") }).to all(include("LIMIT-"))
  end

  it "restores selected project and applies the same project filter to overview and permission rows" do
    selected_project = create(:project, code: "SELECTED", name: "Selected Project")
    other_project = create(:project, code: "OTHER", name: "Other Project")
    selected_document = create(:document, project: selected_project, title: "Selected Permission Document", slug: "selected-permission-document")
    other_document = create(:document, project: other_project, title: "Other Permission Document", slug: "other-permission-document")
    create(:document_permission, document: selected_document, access_level: :view)
    create(:document_permission, document: other_document, access_level: :download)

    sign_in_as(admin_user)

    get selected_project_admin_document_permissions_path(format: :json), params: { id: selected_project.id }
    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("option")).to include("value" => selected_project.id, "text" => "SELECTED / Selected Project")

    get selected_project_admin_document_permissions_path(format: :json), params: { id: "999999" }
    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("option")).to be_nil

    get admin_document_permissions_path(project_id: selected_project.id)

    expect(response).to have_http_status(:ok)
    aggregate_failures do
      expect(project_filter_field["data-rails-fields-kit--tom-select-kind-value"]).to eq("combobox")
      expect(project_filter_field["data-rails-fields-kit--tom-select-url-value"]).to eq(project_search_admin_document_permissions_path(format: :json))
      expect(project_filter_field["data-rails-fields-kit--tom-select-selected-url-value"]).to eq(selected_project_admin_document_permissions_path(format: :json))
      expect(project_filter_field["data-rails-fields-kit--tom-select-max-options-value"]).to eq(Admin::DocumentPermissionsController::PROJECT_SEARCH_LIMIT.to_s)
      expect(selected_project_option["value"]).to eq(selected_project.id.to_s)
      expect(selected_project_option.text).to eq("SELECTED / Selected Project")
      expect(page_text).to include("案件: SELECTED / Selected Project")
      expect(page_text).to include("Selected Permission Document")
      expect(page_text).not_to include("Other Permission Document")
    end
  end

  it "keeps project lookup endpoints inside the admin boundary" do
    project = create(:project, code: "ADMIN", name: "Admin Project")

    sign_in_as(external_user)

    get project_search_admin_document_permissions_path(format: :json), params: { q: project.code }
    expect(response).to have_http_status(:forbidden)

    get selected_project_admin_document_permissions_path(format: :json), params: { id: project.id }
    expect(response).to have_http_status(:forbidden)
  end
end
