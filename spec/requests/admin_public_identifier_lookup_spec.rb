require "rails_helper"

RSpec.describe "Admin public identifier lookup", type: :request do
  let(:admin) { create(:user, :internal) }
  let(:project) { create(:project, code: "LOOKUP", name: "Lookup Project") }
  let!(:document) { create(:document, project:, title: "Lookup Manual", slug: "lookup-manual") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def action_targets
    parsed_html.css("a[href], form[action]").map do |node|
      node["href"] || node["action"]
    end
  end

  def document_params(document, attributes = {})
    {
      project_id: document.project_id,
      title: document.title,
      slug: document.slug,
      category: document.category,
      document_kind: document.document_kind,
      visibility_policy: document.visibility_policy
    }.merge(attributes)
  end

  def project_params(project, attributes = {})
    {
      code: project.code,
      name: project.name,
      description: project.description,
      company_id: project.company_id,
      active: project.active
    }.merge(attributes)
  end

  before do
    sign_in_as(admin)
  end

  describe "admin documents" do
    it "uses public_id-based action links on the index" do
      get admin_documents_path

      expect(response).to have_http_status(:ok)
      expect(action_targets).to include(edit_admin_document_path(document.public_id))
      expect(action_targets).to include(archive_admin_document_path(document.public_id))
      expect(action_targets).to include(admin_document_path(document.public_id))
      expect(action_targets).not_to include(edit_admin_document_path(document.id))
      expect(action_targets).not_to include(archive_admin_document_path(document.id))
      expect(action_targets).not_to include(admin_document_path(document.id))
    end

    it "accepts public_id for document member actions" do
      get edit_admin_document_path(document.public_id)
      expect(response).to have_http_status(:ok)

      patch admin_document_path(document.public_id), params: {
        document: document_params(document, title: "Lookup Manual Updated")
      }
      expect(response).to redirect_to(admin_documents_path)
      expect(document.reload.title).to eq("Lookup Manual Updated")

      patch archive_admin_document_path(document.public_id)
      expect(response).to redirect_to(admin_documents_path)
      expect(document.reload).to be_archived

      patch restore_admin_document_path(document.public_id)
      expect(response).to redirect_to(admin_documents_path)
      expect(document.reload).not_to be_archived

      deletable_document = create(:document, project:, title: "Delete Me", slug: "delete-me")
      expect do
        delete admin_document_path(deletable_document.public_id)
      end.to change(Document, :count).by(-1)
      expect(response).to redirect_to(admin_documents_path)
    end

    it "rejects numeric ids for document member actions without changing the document" do
      get edit_admin_document_path(document.id)
      expect(response).to have_http_status(:not_found)

      patch admin_document_path(document.id), params: {
        document: document_params(document, title: "Numeric Id Update")
      }
      expect(response).to have_http_status(:not_found)
      expect(document.reload.title).to eq("Lookup Manual")

      patch archive_admin_document_path(document.id)
      expect(response).to have_http_status(:not_found)
      expect(document.reload).not_to be_archived

      expect do
        delete admin_document_path(document.id)
      end.not_to change(Document, :count)
      expect(response).to have_http_status(:not_found)
      expect(Document.exists?(document.id)).to be(true)
    end
  end

  describe "admin projects" do
    it "uses code-based action links and member lookup" do
      get admin_projects_path

      expect(response).to have_http_status(:ok)
      expect(action_targets).to include(edit_admin_project_path(project.code))
      expect(action_targets).to include(admin_project_path(project.code))
      expect(action_targets).not_to include(edit_admin_project_path(project.id))
      expect(action_targets).not_to include(admin_project_path(project.id))
      expect(admin_project_path(project)).to eq("/admin/projects/#{project.code}")
      expect(edit_admin_project_path(project)).to eq("/admin/projects/#{project.code}/edit")

      get edit_admin_project_path(project.code)
      expect(response).to have_http_status(:ok)

      patch admin_project_path(project.code), params: {
        project: project_params(project, name: "Lookup Project Updated")
      }
      expect(response).to redirect_to(admin_projects_path)
      expect(project.reload.name).to eq("Lookup Project Updated")
    end

    it "rejects numeric ids for project member lookup without changing the project" do
      get edit_admin_project_path(project.id)
      expect(response).to have_http_status(:not_found)

      patch admin_project_path(project.id), params: {
        project: project_params(project, name: "Numeric Id Project")
      }
      expect(response).to have_http_status(:not_found)
      expect(project.reload.name).to eq("Lookup Project")
    end
  end
end
