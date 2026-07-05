require "rails_helper"

RSpec.describe "Admin document set maintenance mode", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:project) { create(:project, name: "Maintenance Delivery", code: "MAINT-SET") }
  let(:document_a) { create(:document, project:, title: "配布仕様", slug: "delivery-spec") }
  let(:document_b) { create(:document, project:, title: "添付仕様", slug: "attachment-spec") }
  let(:version_a) { create(:document_version, document: document_a, version_label: "v1.0.0") }
  let(:version_b) { create(:document_version, document: document_b, version_label: "v2.0.0") }
  let!(:existing_document_set) do
    create(
      :document_set,
      project:,
      name: "既存配布セット",
      description: "original description",
      set_type: :delivery,
      visibility_policy: :restricted_external,
      sort_order: 1
    )
  end

  before do
    create(
      :document_set_item,
      document_set: existing_document_set,
      document: document_a,
      document_version: version_a,
      sort_order: 1,
      note: "pinned original"
    )
    document_b.update!(latest_version: version_b)
    sign_in_as(admin)
  end

  describe "mutation routes" do
    around do |example|
      with_read_only_maintenance("true") { example.run }
    end

    it "blocks create before saving the document set or its items" do
      expect do
        post admin_document_sets_path, params: {
          document_set: {
            project_id: project.id,
            name: "停止中セット",
            description: "blocked create",
            set_type: "delivery",
            visibility_policy: "restricted_external",
            sort_order: 2
          },
          document_set_items: {
            "0" => {
              selected: "1",
              document_id: document_b.id,
              document_version_id: version_b.id,
              sort_order: "2",
              note: "blocked item"
            }
          }
        }
      end.not_to change(DocumentSet, :count)

      expect(DocumentSet.find_by(name: "停止中セット")).to be_nil
      expect(response).to redirect_to(admin_document_sets_path)
      follow_redirect!
      expect(response.body).to include("メンテナンス中のため文書セットの作成・更新・削除は停止しています")
    end

    it "blocks update before changing attributes or rebuilding items" do
      original_items = existing_document_set.document_set_items.order(:sort_order).pluck(
        :document_id,
        :document_version_id,
        :sort_order,
        :note
      )

      expect do
        patch admin_document_set_path(existing_document_set), params: {
          document_set: {
            project_id: project.id,
            name: "更新されないセット",
            description: "blocked update",
            set_type: "design",
            visibility_policy: "internal_only",
            sort_order: 9
          },
          document_set_items: {
            "0" => {
              selected: "1",
              document_id: document_b.id,
              document_version_id: version_b.id,
              sort_order: "8",
              note: "replacement blocked"
            }
          }
        }
      end.not_to change(DocumentSetItem, :count)

      expect(response).to redirect_to(admin_document_sets_path)
      expect(existing_document_set.reload).to have_attributes(
        name: "既存配布セット",
        description: "original description",
        set_type: "delivery",
        visibility_policy: "restricted_external",
        sort_order: 1
      )
      expect(existing_document_set.document_set_items.order(:sort_order).pluck(:document_id, :document_version_id, :sort_order, :note)).to eq(original_items)
    end

    it "blocks destroy before deleting the document set" do
      expect do
        delete admin_document_set_path(existing_document_set)
      end.not_to change(DocumentSet, :count)

      expect(response).to redirect_to(admin_document_sets_path)
      expect(existing_document_set.reload).to be_present
    end
  end

  describe "read-only routes" do
    around do |example|
      with_read_only_maintenance("true") { example.run }
    end

    it "keeps admin index, export metadata, CSV, search, and public viewer readable" do
      get admin_document_sets_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("既存配布セット")

      get admin_document_sets_path(format: :json), params: { q: "配布" }
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to include(
        "report_type" => "document_sets",
        "export_scope" => "current_filters",
        "row_count" => 1
      )

      get admin_document_sets_path(format: :csv), params: { q: "配布" }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("文書セット名")
      expect(response.body).to include("既存配布セット")

      get project_search_admin_document_sets_path(format: :json), params: { q: "MAINT" }
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).fetch("options")).to include(include("value" => project.id, "text" => "MAINT-SET / Maintenance Delivery"))

      get document_search_admin_document_sets_path(format: :json), params: { project_id: project.id, q: "配布" }
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).fetch("documents")).to include(include("id" => document_a.id, "title" => "配布仕様"))

      get document_version_search_admin_document_sets_path(format: :json), params: { project_id: project.id, document_id: document_a.id, q: "v1" }
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).fetch("versions")).to include(include("id" => version_a.id, "version_label" => "v1.0.0"))

      get project_document_sets_path(project)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("既存配布セット")

      get project_document_set_path(project, existing_document_set)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("既存配布セット")
      expect(response.body).to include("pinned original")
    end
  end

  describe "when maintenance mode is disabled" do
    around do |example|
      with_read_only_maintenance(nil) { example.run }
    end

    it "keeps the existing destroy behavior" do
      expect do
        delete admin_document_set_path(existing_document_set)
      end.to change(DocumentSet, :count).by(-1)

      expect(response).to redirect_to(admin_document_sets_path)
    end
  end

  def with_read_only_maintenance(value)
    original_value = ENV[Admin::DocumentSetsController::READ_ONLY_MAINTENANCE_ENV]
    ENV[Admin::DocumentSetsController::READ_ONLY_MAINTENANCE_ENV] = value
    yield
  ensure
    if original_value.nil?
      ENV.delete(Admin::DocumentSetsController::READ_ONLY_MAINTENANCE_ENV)
    else
      ENV[Admin::DocumentSetsController::READ_ONLY_MAINTENANCE_ENV] = original_value
    end
  end
end
