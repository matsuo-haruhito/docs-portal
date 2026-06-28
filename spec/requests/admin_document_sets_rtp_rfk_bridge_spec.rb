require "rails_helper"

RSpec.describe "Admin document sets RTP RFK bridge canary", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:project) { create(:project, code: "CANARY", name: "Canary Project") }
  let(:other_project) { create(:project, code: "OTHER", name: "Other Project") }
  let!(:document) { create(:document, project:, title: "Canary Manual", slug: "canary-manual") }
  let!(:other_document) { create(:document, project: other_project, title: "Canary Manual Outside", slug: "outside-canary") }
  let!(:document_set) do
    create(
      :document_set,
      project:,
      name: "Canary delivery set",
      set_type: :delivery,
      visibility_policy: :restricted_external,
      sort_order: 1
    )
  end

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def json_body
    JSON.parse(response.body)
  end

  def table_preference_table
    parsed_html.at_css(%(table[data-rails-table-preferences-table-key-value="admin_document_sets"]))
  end

  def table_preference_columns
    JSON.parse(table_preference_table["data-rails-table-preferences-columns-value"])
  end

  def project_combobox
    parsed_html.at_css(%(select[name="document_set[project_id]"]))
  end

  def remote_document_picker
    parsed_html.at_css(%(select[name="document_set_remote_document_id"]))
  end

  it "keeps RTP table metadata and RFK form metadata visible on the canary screen" do
    sign_in_as(admin)

    get admin_document_sets_path

    expect(response).to have_http_status(:ok)

    expect(table_preference_table).to be_present
    expect(table_preference_columns.map { |column| column.fetch("key") }).to eq(
      %w[project name set_type visibility_policy documents_count actions]
    )
    expect(table_preference_columns.find { |column| column.fetch("key") == "set_type" }).to include(
      "filter" => include("type" => "select", "param" => "set_type")
    )
    expect(table_preference_columns.find { |column| column.fetch("key") == "visibility_policy" }).to include(
      "filter" => include("type" => "select", "param" => "visibility_policy")
    )

    expect(project_combobox).to be_present
    expect(project_combobox["data-controller"]).to include("rails-fields-kit--tom-select")
    expect(project_combobox["data-rails-fields-kit--tom-select-kind-value"]).to eq("combobox")
    expect(project_combobox["data-rails-fields-kit--tom-select-url-value"]).to eq(
      project_search_admin_document_sets_path(format: :json)
    )
    expect(project_combobox["data-rails-fields-kit--tom-select-selected-url-value"]).to eq(
      selected_project_admin_document_sets_path(format: :json)
    )
    expect(project_combobox["data-rails-fields-kit--tom-select-max-options-value"]).to eq(
      Admin::DocumentSetsController::PROJECT_SEARCH_LIMIT.to_s
    )
  end

  it "keeps RFK selected state and host-owned endpoint scope separate from RTP table state" do
    sign_in_as(admin)

    post admin_document_sets_path(set_type: "delivery"), params: {
      document_set: {
        project_id: project.id,
        name: "",
        description: "invalid canary rerender",
        set_type: "delivery",
        visibility_policy: "restricted_external",
        sort_order: 2
      },
      document_set_items: {
        "0" => {
          selected: "1",
          document_id: document.id,
          document_version_id: "",
          sort_order: "3",
          note: "keep selected row"
        }
      }
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(parsed_html.at_css(%(option[value="#{project.id}"][selected]))&.text&.squish).to eq("CANARY / Canary Project")
    expect(remote_document_picker["data-rails-fields-kit--tom-select-url-value"]).to eq(
      document_search_admin_document_sets_path(project_id: project.id)
    )
    expect(parsed_html.at_css(%(tr[data-document-set-document-filter-document-id="#{document.id}"] input[type="checkbox"][checked]))).to be_present
    expect(parsed_html.at_css(%(form[action="#{admin_document_sets_path(set_type: "delivery")}"]))).to be_present

    get document_search_admin_document_sets_path, params: { project_id: project.id, q: "Canary" }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("documents")).to contain_exactly(
      a_hash_including("id" => document.id, "title" => "Canary Manual", "slug" => "canary-manual")
    )
    expect(json_body.fetch("documents")).not_to include(a_hash_including("id" => other_document.id))
  end
end
