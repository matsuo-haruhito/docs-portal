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
    expect(select.at_css(%(option[value="#{selected_version.id}"][selected]))).to be_present
    expect(option_values(select)).not_to include(*unrendered_versions.map { _1.id.to_s })
    expect(select["data-rails-fields-kit--tom-select-url-value"]).to eq(
      document_version_search_admin_document_sets_path(project_id: project.id, document_id: document.id)
    )
    expect(select["data-rails-fields-kit--tom-select-max-options-value"]).to eq("20")

    other_select = fixed_version_select_for(other_document)
    expect(option_values(other_select)).to eq([""])
    expect(option_values(other_select)).not_to include(other_document_version.id.to_s)
  end

  it "returns project-scoped fixed version search results with a bounded limit" do
    versions = Array.new(25) do |index|
      create(:document_version, document:, version_label: "release-search-#{index.to_s.rjust(2, "0")}")
    end
    other_project = create(:project, name: "Other Version Project")
    other_project_document = create(:document, project: other_project, title: "外部候補", slug: "outside-candidate")
    create(:document_version, document: other_project_document, version_label: "release-search-leak")

    sign_in_as(admin)

    get document_version_search_admin_document_sets_path, params: { project_id: project.id, document_id: document.id, q: "release-search" }

    expect(response).to have_http_status(:ok)
    option_ids = json_body.fetch("options").map { _1.fetch("id") }
    expect(option_ids.size).to eq(20)
    expect(option_ids).to all(be_in(versions.map(&:id)))
    expect(json_body.fetch("versions")).to eq(json_body.fetch("options"))
    expect(json_body.fetch("options").map { _1.fetch("text") }).to all(include("release-search"))
  end
end
