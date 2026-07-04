require "rails_helper"

RSpec.describe "Admin document maintenance mode", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "DOCMAINT", name: "Document Maintenance") }
  let(:active_document) do
    create(
      :document,
      project:,
      title: "Maintenance Active Document",
      slug: "maintenance-active-document",
      category: :spec,
      document_kind: :markdown,
      visibility_policy: :internal_only
    )
  end
  let(:archived_document) do
    create(
      :document,
      project:,
      title: "Maintenance Archived Document",
      slug: "maintenance-archived-document",
      category: :spec,
      document_kind: :markdown,
      visibility_policy: :internal_only
    ).tap { |document| document.archive!(actor: admin_user) }
  end

  around do |example|
    original_value = ENV[Admin::DocumentsController::READ_ONLY_MAINTENANCE_ENV]
    ENV[Admin::DocumentsController::READ_ONLY_MAINTENANCE_ENV] = maintenance_env_value
    example.run
  ensure
    if original_value.nil?
      ENV.delete(Admin::DocumentsController::READ_ONLY_MAINTENANCE_ENV)
    else
      ENV[Admin::DocumentsController::READ_ONLY_MAINTENANCE_ENV] = original_value
    end
  end

  before do
    sign_in_as(admin_user)
  end

  describe "when read-only maintenance is enabled" do
    let(:maintenance_env_value) { "1" }

    it "blocks document master create, update, archive, restore, and destroy" do
      expect do
        post admin_documents_path, params: {
          document: {
            project_id: project.id,
            title: "Blocked Maintenance Document",
            slug: "blocked-maintenance-document",
            category: "spec",
            document_kind: "markdown",
            visibility_policy: "internal_only"
          }
        }
      end.not_to change(Document, :count)
      expect(response).to redirect_to(admin_documents_path)

      follow_redirect!
      expect(response.body).to include("メンテナンス中のため文書マスタの登録・編集・アーカイブ・復元・削除は停止しています")

      patch admin_document_path(active_document.public_id), params: {
        document: {
          project_id: project.id,
          title: "Blocked Updated Title",
          slug: active_document.slug,
          category: active_document.category,
          document_kind: active_document.document_kind,
          visibility_policy: active_document.visibility_policy
        }
      }
      expect(response).to redirect_to(admin_documents_path)
      expect(active_document.reload.title).to eq("Maintenance Active Document")

      patch archive_admin_document_path(active_document.public_id), params: {
        retention_until: 1.month.from_now.to_date.to_s,
        discard_candidate_at: 2.months.from_now.to_date.to_s
      }
      expect(response).to redirect_to(admin_documents_path)
      expect(active_document.reload).not_to be_archived
      expect(active_document.retention_until).to be_nil
      expect(active_document.discard_candidate_at).to be_nil

      patch restore_admin_document_path(archived_document.public_id)
      expect(response).to redirect_to(admin_documents_path)
      expect(archived_document.reload).to be_archived

      expect do
        delete admin_document_path(active_document.public_id)
      end.not_to change(Document, :count)
      expect(response).to redirect_to(admin_documents_path)
      expect(Document.exists?(active_document.id)).to be(true)
    end

    it "keeps document master read-only screens, project lookup, and lifecycle handoff readable" do
      active_document

      get admin_documents_path, params: { q: "DOCMAINT" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Maintenance Active Document")

      get edit_admin_document_path(active_document.public_id)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Maintenance Active Document")

      get project_search_admin_documents_path(format: :json), params: { q: "docmaint" }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).fetch("options")).to include(
        include("value" => project.id, "text" => "DOCMAINT / Document Maintenance")
      )

      get lifecycle_handoff_admin_documents_path(format: :json), params: { q: "DOCMAINT" }

      expect(response).to have_http_status(:ok)
      payload = JSON.parse(response.body)
      expect(payload.fetch("total_count")).to eq(1)
      expect(payload.fetch("note")).to include("read-only handoff")
      expect(payload.fetch("candidates")).to include(
        include("public_id" => active_document.public_id, "title" => "Maintenance Active Document")
      )
    end
  end

  describe "when read-only maintenance is disabled" do
    let(:maintenance_env_value) { nil }

    it "keeps the existing document master archive and restore behavior" do
      patch archive_admin_document_path(active_document.public_id)

      expect(response).to redirect_to(admin_documents_path)
      expect(active_document.reload).to be_archived

      patch restore_admin_document_path(active_document.public_id)

      expect(response).to redirect_to(admin_documents_path)
      expect(active_document.reload).not_to be_archived
    end
  end
end
