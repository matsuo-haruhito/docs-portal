require "rails_helper"

RSpec.describe "Admin documents project select", type: :request do
  let(:admin) { create(:user, :admin) }
  let!(:project) { create(:project, code: "DOCS-001", name: "Docs Project") }
  let!(:other_project) { create(:project, code: "DOCS-002", name: "Other Project") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def project_field
    parsed_html.at_css('[name="document[project_id]"]')
  end

  it "uses rails_fields_kit for only the document project selector" do
    form_source = Rails.root.join("app/views/admin/documents/_form.html.slim").read

    aggregate_failures do
      expect(form_source).to include("= form.rfk_combobox :project_id,")
      expect(form_source).to include("collection: []")
      expect(form_source).to include("selected: admin_document_project_selected_option(document.project)")
      expect(form_source).to include("url: project_search_admin_documents_path(format: :json)")
      expect(form_source).to include("selected_url: selected_project_admin_documents_path(format: :json)")
      expect(form_source).to include('value_field: "value"')
      expect(form_source).to include('label_field: "text"')
      expect(form_source).to include('search_field: "text"')
      expect(form_source).to include("max_options: Admin::DocumentsController::PROJECT_SEARCH_LIMIT")
      expect(form_source).to include('label: "案件"')
      expect(form_source).to include('placeholder: "案件コード・案件名で検索"')
      expect(form_source).not_to include("collection_select :project_id")
      expect(form_source).not_to include("= form.rfk_select :project_id")
      expect(form_source).to include("= form.select :category")
      expect(form_source).to include("= form.select :document_kind")
      expect(form_source).to include("= form.select :visibility_policy")
    end
  end

  it "renders the document project field on the index form" do
    sign_in_as(admin)

    get admin_documents_path

    expect(response).to have_http_status(:ok)
    expect(project_field).to be_present
    expect(project_field["name"]).to eq("document[project_id]")
    expect(project_field["id"]).to eq("document_project_id")
    expect(project_field["data-rails-fields-kit--tom-select-url-value"]).to eq(project_search_admin_documents_path(format: :json))
    expect(project_field["data-rails-fields-kit--tom-select-selected-url-value"]).to eq(selected_project_admin_documents_path(format: :json))
    expect(project_field["data-rails-fields-kit--tom-select-max-options-value"]).to eq(Admin::DocumentsController::PROJECT_SEARCH_LIMIT.to_s)
  end

  it "keeps the existing document project selected on the edit form" do
    document = create(:document, project: other_project, title: "既存文書", slug: "existing-doc")

    sign_in_as(admin)

    get edit_admin_document_path(document.public_id)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("DOCS-002 / Other Project")
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
    expect(page_text).to include("DOCS-002 / Other Project")
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
    expect(page_text).to include("DOCS-002 / Other Project")
    expect(document.reload.project_id).to eq(project.id)
  end
end
