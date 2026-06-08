require "rails_helper"

RSpec.describe "Admin document set project picker", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:external_user) { create(:user, :external) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def json_body
    JSON.parse(response.body)
  end

  def project_picker
    parsed_html.at_css('select[name="document_set[project_id]"]')
  end

  it "returns bounded project search results by code and name" do
    code_match = create(:project, code: "ALPHA-100", name: "Operations Hub")
    name_match = create(:project, code: "BETA-200", name: "Remote Workspace")

    max_length = Admin::DocumentSetsController::PROJECT_SEARCH_QUERY_MAX_LENGTH
    bounded_query = "remote-" + ("a" * (max_length - "remote-".length))
    bounded_match = create(:project, code: "BOUND-100", name: "Target #{bounded_query}")
    suffix_only = create(:project, code: "BOUND-200", name: "Suffix only project")
    21.times do |index|
      create(:project, code: format("LIMIT-%02d", index), name: format("Limit Project %02d", index))
    end

    sign_in_as(admin)

    get project_search_admin_document_sets_path, params: { q: "alpha" }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options")).to contain_exactly(
      a_hash_including("value" => code_match.id, "text" => "ALPHA-100 / Operations Hub")
    )

    get project_search_admin_document_sets_path, params: { q: "workspace" }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options")).to contain_exactly(
      a_hash_including("value" => name_match.id, "text" => "BETA-200 / Remote Workspace")
    )

    get project_search_admin_document_sets_path, params: { q: "  #{bounded_query}   suffix  " }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options")).to contain_exactly(
      a_hash_including("value" => bounded_match.id, "text" => "BOUND-100 / Target #{bounded_query}")
    )
    expect(json_body.fetch("options")).not_to include(a_hash_including("value" => suffix_only.id))

    get project_search_admin_document_sets_path, params: { q: "limit" }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options").size).to eq(Admin::DocumentSetsController::PROJECT_SEARCH_LIMIT)
    expect(json_body.fetch("options").map { |option| option.fetch("text") }).to all(start_with("LIMIT-"))
  end

  it "returns selected project options for edit and rerender restoration" do
    project = create(:project, code: "DOC-SET", name: "Document Set Project")

    sign_in_as(admin)

    get selected_project_admin_document_sets_path, params: { id: project.id }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("option")).to include(
      "value" => project.id,
      "text" => "DOC-SET / Document Set Project"
    )

    get selected_project_admin_document_sets_path, params: { id: "missing" }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("option")).to be_nil
  end

  it "renders the remote project combobox and restores the selected project on invalid create" do
    project = create(:project, code: "FORM-100", name: "Form Project")
    create(:document, project:, title: "Form Document", slug: "form-document")
    document_set = create(:document_set, project:, name: "Saved Set")

    sign_in_as(admin)

    get admin_document_sets_path

    expect(response).to have_http_status(:ok)
    picker = project_picker
    expect(picker).to be_present
    expect(picker["data-controller"]).to include("rails-fields-kit--tom-select")
    expect(picker["data-rails-fields-kit--tom-select-kind-value"]).to eq("combobox")
    expect(picker["data-rails-fields-kit--tom-select-url-value"]).to eq(project_search_admin_document_sets_path(format: :json))
    expect(picker["data-rails-fields-kit--tom-select-selected-url-value"]).to eq(selected_project_admin_document_sets_path(format: :json))
    expect(picker["data-rails-fields-kit--tom-select-value-field-value"]).to eq("value")
    expect(picker["data-rails-fields-kit--tom-select-label-field-value"]).to eq("text")
    expect(picker["data-rails-fields-kit--tom-select-search-field-value"]).to eq("text")
    expect(picker["data-rails-fields-kit--tom-select-min-length-value"]).to eq("1")
    expect(picker["data-rails-fields-kit--tom-select-max-options-value"]).to eq("20")

    post admin_document_sets_path, params: {
      document_set: {
        project_id: project.id,
        name: "",
        description: "selected project restore",
        set_type: "delivery",
        visibility_policy: "restricted_external",
        sort_order: 0
      },
      document_set_items: {}
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(project_picker.at_css(%(option[value="#{project.id}"][selected]))&.text&.squish).to eq("FORM-100 / Form Project")
    expect(response.body).to include("文書名 / URL識別子で探す")

    get edit_admin_document_set_path(document_set)

    expect(response).to have_http_status(:ok)
    expect(project_picker.at_css(%(option[value="#{project.id}"][selected]))&.text&.squish).to eq("FORM-100 / Form Project")
  end

  it "forbids external users from project picker JSON endpoints" do
    project = create(:project)

    sign_in_as(external_user)

    get project_search_admin_document_sets_path, params: { q: project.code }

    expect(response).to have_http_status(:forbidden)

    get selected_project_admin_document_sets_path, params: { id: project.id }

    expect(response).to have_http_status(:forbidden)
  end
end
