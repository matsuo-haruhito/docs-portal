require "rails_helper"

RSpec.describe "Admin document project search", type: :request do
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
    parsed_html.at_css('[name="document[project_id]"]')
  end

  it "renders the document project field as a bounded remote combobox" do
    sign_in_as(admin_user)

    get admin_documents_path

    expect(response).to have_http_status(:ok)
    expect(project_field).to be_present
    expect(project_field["data-rails-fields-kit--tom-select-url-value"]).to eq(project_search_admin_documents_path(format: :json))
    expect(project_field["data-rails-fields-kit--tom-select-selected-url-value"]).to eq(selected_project_admin_documents_path(format: :json))
    expect(project_field["data-rails-fields-kit--tom-select-value-field-value"]).to eq("value")
    expect(project_field["data-rails-fields-kit--tom-select-label-field-value"]).to eq("text")
    expect(project_field["data-rails-fields-kit--tom-select-max-options-value"]).to eq(Admin::DocumentsController::PROJECT_SEARCH_LIMIT.to_s)
  end

  it "returns project options by code and name while bounding query length and result count" do
    max_length = Admin::DocumentsController::PROJECT_SEARCH_QUERY_MAX_LENGTH
    bounded_query = "remote-" + ("a" * (max_length - "remote-".length))
    code_match = create(:project, code: "REMOTE-001", name: "Code Match")
    name_match = create(:project, code: "NAME-001", name: "Project #{bounded_query}")
    suffix_only = create(:project, code: "SUFFIX-001", name: "needle only")
    21.times do |index|
      create(:project, code: format("LIMIT-%02d", index), name: "Limit Project #{index}")
    end

    sign_in_as(admin_user)

    get project_search_admin_documents_path(format: :json), params: { q: "REMOTE-001" }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options")).to include(
      a_hash_including("value" => code_match.id, "text" => "#{code_match.code} / #{code_match.name}")
    )

    get project_search_admin_documents_path(format: :json), params: { q: "  #{bounded_query} needle  " }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options")).to contain_exactly(
      a_hash_including("value" => name_match.id, "text" => "#{name_match.code} / #{name_match.name}")
    )
    expect(json_body.fetch("options")).not_to include(a_hash_including("value" => suffix_only.id))

    get project_search_admin_documents_path(format: :json), params: { q: "LIMIT-" }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options").size).to eq(Admin::DocumentsController::PROJECT_SEARCH_LIMIT)
    expect(json_body.fetch("options").map { |option| option.fetch("text") }).to all(start_with("LIMIT-"))
  end

  it "returns the selected project option for saved and rerendered document forms" do
    project = create(:project, code: "SEL-001", name: "Selected Project")
    document = create(:document, project:, title: "Selected Document")

    sign_in_as(admin_user)

    get selected_project_admin_documents_path(format: :json), params: { id: project.id }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("option")).to include(
      "value" => project.id,
      "text" => "SEL-001 / Selected Project"
    )

    get edit_admin_document_path(document.public_id)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("SEL-001 / Selected Project")

    post admin_documents_path, params: {
      document: {
        project_id: project.id,
        title: "",
        slug: "invalid-selected-document",
        category: "spec",
        document_kind: "markdown",
        visibility_policy: "internal_only"
      }
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(page_text).to include("SEL-001 / Selected Project")
  end

  it "keeps project lookup endpoints inside the admin boundary" do
    project = create(:project, code: "ADMIN-ONLY", name: "Admin Only")

    sign_in_as(external_user)

    get project_search_admin_documents_path(format: :json), params: { q: project.code }
    expect(response).to have_http_status(:forbidden)

    get selected_project_admin_documents_path(format: :json), params: { id: project.id }
    expect(response).to have_http_status(:forbidden)
  end
end
