require "rails_helper"

RSpec.describe "Admin Microsoft Graph connection project search", type: :request do
  let(:admin_user) { create(:user, :internal) }

  before do
    sign_in_as(admin_user)
  end

  def json_body
    JSON.parse(response.body)
  end

  it "returns project options by code and name for the remote combobox" do
    alpha_project = create(:project, code: "GRAPH001", name: "Alpha Docs")
    beta_project = create(:project, code: "OPS002", name: "Beta Archive")

    get project_search_admin_microsoft_graph_connections_path(format: :json), params: { q: "graph001" }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options")).to contain_exactly(
      include("value" => alpha_project.id, "text" => "GRAPH001 / Alpha Docs")
    )

    get project_search_admin_microsoft_graph_connections_path(format: :json), params: { q: "beta archive" }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options")).to contain_exactly(
      include("value" => beta_project.id, "text" => "OPS002 / Beta Archive")
    )
  end

  it "bounds project search results and handles long queries without a server error" do
    22.times do |index|
      create(:project, code: format("MSG%02d", index), name: "Bounded Project #{index}")
    end

    get project_search_admin_microsoft_graph_connections_path(format: :json), params: { q: "Bounded Project" }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options").size).to eq(Admin::MicrosoftGraphConnectionsController::PROJECT_SEARCH_LIMIT)

    long_query = "Bounded Project" + ("x" * 200)
    get project_search_admin_microsoft_graph_connections_path(format: :json), params: { q: long_query }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options")).to eq([])
  end

  it "restores a selected project even when it is outside the search result window" do
    22.times do |index|
      create(:project, code: format("AAA%02d", index), name: "Listed Project #{index}")
    end
    selected_project = create(:project, code: "ZZZ99", name: "Selected Project")

    get selected_project_admin_microsoft_graph_connections_path(format: :json), params: { id: selected_project.id }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("option")).to include(
      "value" => selected_project.id,
      "text" => "ZZZ99 / Selected Project"
    )

    get selected_project_admin_microsoft_graph_connections_path(format: :json), params: { id: "999999" }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("option")).to be_nil
  end

  it "renders the project combobox with a selected project on edit" do
    project = create(:project, code: "EDIT01", name: "Edit Project")
    connection = create(:microsoft_graph_connection, project:, name: "Edit connection")

    get edit_admin_microsoft_graph_connection_path(connection)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(project_search_admin_microsoft_graph_connections_path(format: :json))
    expect(response.body).to include(selected_project_admin_microsoft_graph_connections_path(format: :json))
    expect(response.body).to include("EDIT01 / Edit Project")
    expect(response.body).not_to include("new TomSelect")
  end

  it "keeps the selected project visible after validation rerender" do
    project = create(:project, code: "VALID01", name: "Validation Project")

    post admin_microsoft_graph_connections_path, params: {
      microsoft_graph_connection: {
        project_id: project.id,
        name: "",
        auth_type: "client_credentials",
        tenant_id: "tenant-id",
        client_id: "client-id",
        client_secret: "client-secret",
        site_id: "site-id",
        drive_id: "drive-id",
        preview_folder_path: "docs-portal-previews",
        enabled: "true"
      }
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("VALID01 / Validation Project")
    expect(response.body).to include(project_search_admin_microsoft_graph_connections_path(format: :json))
    expect(response.body).to include(selected_project_admin_microsoft_graph_connections_path(format: :json))
  end
end
