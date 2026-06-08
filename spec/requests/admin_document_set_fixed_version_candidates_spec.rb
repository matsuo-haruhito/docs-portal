require "rails_helper"

RSpec.describe "Admin document set fixed version candidates", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:project) { create(:project, name: "Version Candidate Project") }
  let(:document) { create(:document, project:, title: "候補文書", slug: "candidate-doc") }
  let(:other_document) { create(:document, project:, title: "別文書", slug: "other-doc") }
  let!(:selected_version) { create(:document_version, document:, version_label: "release-selected") }
  let!(:other_document_version) { create(:document_version, document: other_document, version_label: "release-other-doc") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def json_body
    JSON.parse(response.body)
  end

  def document_row_for(row_document)
    parsed_html.at_css(%(tr[data-document-set-document-filter-document-id="#{row_document.id}"]))
  end

  def fixed_version_select_for(row_document)
    document_row_for(row_document).at_css('select[name$="[document_version_id]"]')
  end

  def option_values(select)
    select.css("option").map { _1["value"] }
  end

  it "renders only the blank and selected fixed version options on invalid rerender" do
    unrendered_versions = Array.new(25) do |index|
      create(:document_version, document:, version_label: "release-bulk-#{index.to_s.rjust(2, "0")}")
    end

    sign_in_as(admin)

    post admin_document_sets_path, params: {
      document_set: {
        project_id: project.id,
        name: "",
        description: "bounded fixed versions",
        set_type: "delivery",
        visibility_policy: "restricted_external",
        sort_order: 0
      },
      document_set_items: {
        "0" => {
          selected: "1",
          document_id: document.id,
          document_version_id: selected_version.id,
          sort_order: "1",
          note: "fixed"
        }
      }
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("固定版候補は文書ごとに検索して選びます。")

    select = fixed_version_select_for(document)
    expect(option_values(select)).to eq(["", selected_version.id.to_s])
    selected_option = select.at_css(%(option[value="#{selected_version.id}"][selected]))
    expect(selected_option).to be_present
    expect(selected_option.text).to include("release-selected")
    expect(option_values(select)).not_to include(*unrendered_versions.map { _1.id.to_s })
    expect(select["data-rails-fields-kit--tom-select-url-value"]).to eq(
      document_version_search_admin_document_sets_path(project_id: project.id, document_id: document.id)
    )
    expect(select["data-rails-fields-kit--tom-select-max-options-value"]).to eq("20")

    other_select = fixed_version_select_for(other_document)
    expect(option_values(other_select)).to eq([""])
    expect(option_values(other_select)).not_to include(other_document_version.id.to_s)
  end

  it "renders the saved fixed version option on edit" do
    document_set = create(
      :document_set,
      project:,
      name: "保存済み固定版セット",
      set_type: :delivery,
      visibility_policy: :restricted_external
    )
    create(
      :document_set_item,
      document_set:,
      document:,
      document_version: selected_version,
      sort_order: 1,
      note: "saved fixed version"
    )

    sign_in_as(admin)

    get edit_admin_document_set_path(document_set)

    expect(response).to have_http_status(:ok)
    select = fixed_version_select_for(document)
    expect(option_values(select)).to eq(["", selected_version.id.to_s])
    selected_option = select.at_css(%(option[value="#{selected_version.id}"][selected]))
    expect(selected_option).to be_present
    expect(selected_option.text).to include("release-selected")
  end

  it "returns project-scoped fixed version search results with a bounded query and limit" do
    bounded_query = "x" * Admin::DocumentSetsController::DOCUMENT_VERSION_SEARCH_QUERY_MAX_LENGTH
    long_query = "  #{bounded_query}not-used-by-search  "
    versions = Array.new(25) do |index|
      create(:document_version, document:, version_label: "#{bounded_query}-#{index.to_s.rjust(2, "0")}")
    end
    create(:document_version, document:, version_label: "not-matching-version")
    other_project = create(:project, name: "Other Version Project")
    other_project_document = create(:document, project: other_project, title: "外部候補", slug: "outside-candidate")
    create(:document_version, document: other_project_document, version_label: "#{bounded_query}-leak")

    sign_in_as(admin)

    get document_version_search_admin_document_sets_path, params: { project_id: project.id, document_id: document.id, q: long_query }

    expect(response).to have_http_status(:ok)
    options = json_body.fetch("options")
    option_ids = options.map { _1.fetch("id") }
    expect(option_ids.size).to eq(Admin::DocumentSetsController::DOCUMENT_VERSION_SEARCH_LIMIT)
    expect(option_ids).to all(be_in(versions.map(&:id)))
    expect(json_body.fetch("versions")).to eq(options)
    expect(options.map { _1.fetch("version_label") }).to all(include(bounded_query))
    expect(options.map { _1.fetch("version_label") }).not_to include("#{bounded_query}-leak", "not-matching-version")
  end

  it "keeps fixed version search scoped to the selected project document" do
    other_project = create(:project, name: "Other Version Project")
    other_project_document = create(:document, project: other_project, title: "外部候補", slug: "outside-candidate")
    create(:document_version, document: other_project_document, version_label: "outside-v1")

    sign_in_as(admin)

    get document_version_search_admin_document_sets_path, params: {
      project_id: project.id,
      document_id: other_project_document.id,
      q: "outside"
    }

    expect(response).to have_http_status(:not_found)
  end
end
