require "rails_helper"

RSpec.describe "Admin documents project select", type: :request do
  let(:admin) { create(:user, :admin) }
  let!(:project) { create(:project, code: "DOCS-001", name: "Docs Project") }
  let!(:other_project) { create(:project, code: "DOCS-002", name: "Other Project") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def project_select
    parsed_html.at_css('select[name="document[project_id]"]')
  end

  def project_option_values
    project_select.css("option").map { |node| node["value"] }
  end

  def selected_project_value
    project_select.css("option[selected]").first&.[]("value")
  end

  it "renders the new document project field through rails_fields_kit on the index form" do
    sign_in_as(admin)

    get admin_documents_path

    expect(response).to have_http_status(:ok)
    expect(project_select).to be_present
    expect(project_select["name"]).to eq("document[project_id]")
    expect(project_select["id"]).to eq("document_project_id")
    expect(project_option_values).to include(project.id.to_s, other_project.id.to_s)
    expect(response.body).to include("rails-fields-kit")
  end

  it "keeps the existing document project selected on the edit form" do
    document = create(:document, project: other_project, title: "既存文書", slug: "existing-doc")

    sign_in_as(admin)

    get edit_admin_document_path(document.public_id)

    expect(response).to have_http_status(:ok)
    expect(selected_project_value).to eq(other_project.id.to_s)
  end

  it "keeps the submitted project selected after an invalid create rerender" do
    sign_in_as(admin)

    post admin_documents_path, params: {
      document: {
        project_id: other_project.id,
        title: "",
        slug: "invalid-create",
        category: "spec",
        document_kind: "markdown",
        visibility_policy: "internal_only"
      }
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(selected_project_value).to eq(other_project.id.to_s)
  end

  it "keeps the submitted project selected after an invalid update rerender" do
    document = create(:document, project: project, title: "更新前", slug: "update-target")

    sign_in_as(admin)

    patch admin_document_path(document.public_id), params: {
      document: {
        project_id: other_project.id,
        title: "",
        slug: document.slug,
        category: document.category,
        document_kind: document.document_kind,
        visibility_policy: document.visibility_policy
      }
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(selected_project_value).to eq(other_project.id.to_s)
    expect(document.reload.project_id).to eq(project.id)
  end
end
