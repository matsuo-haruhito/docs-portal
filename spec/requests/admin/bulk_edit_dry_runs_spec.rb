require "rails_helper"

RSpec.describe "Admin bulk edit dry runs", type: :request do
  let(:admin_user) { create(:user, :admin) }
  let(:preview_class) { Class.new }
  let(:executor_class) { Class.new }

  before do
    stub_const("DocumentBulkEditPreview", preview_class)
    stub_const("DocumentBulkEditExecutor", executor_class)
  end

  describe "POST /admin/bulk_edit_dry_runs" do
    it "passes selected documents and normalized changes to the preview service" do
      sign_in_as(admin_user)
      document = create(:document)
      other_document = create(:document, project: document.project, title: "Other document", slug: "other-document")
      dry_run = create(:bulk_edit_dry_run, created_by: admin_user, target_document_ids: [document.id, other_document.id])
      preview_service = double("DocumentBulkEditPreview", call: double(bulk_edit_dry_run: dry_run))
      expected_changes = {
        document_attributes: {
          "category" => "manual",
          "visibility_policy" => "internal_only",
          "recommended_sort_order" => "10"
        },
        latest_version_attributes: {
          "snapshot_kind" => "release",
          "published_until" => "2026-12-31"
        },
        add_tag_names: %w[alpha beta gamma delta],
        remove_tag_names: %w[old legacy],
        archive: true
      }

      expect(preview_class).to receive(:new).with(
        actor: admin_user,
        documents: contain_exactly(document, other_document),
        changes: expected_changes
      ).and_return(preview_service)

      post admin_bulk_edit_dry_runs_path, params: {
        bulk_edit: {
          document_ids: ["", document.id, other_document.id, document.id],
          document_attributes: {
            category: "manual",
            document_kind: "",
            visibility_policy: "internal_only",
            importance_level: "",
            recommended_sort_order: "10",
            retention_until: ""
          },
          latest_version_attributes: {
            snapshot_kind: "release",
            published_from: "",
            published_until: "2026-12-31"
          },
          tag_changes: {
            add_tag_names: "alpha, beta、gamma\n delta",
            remove_tag_names: "old\nlegacy"
          },
          archive_action: "archive"
        }
      }

      expect(response).to redirect_to(admin_bulk_edit_dry_run_path(dry_run))
      expect(flash[:notice]).to eq("一括編集dry-runを作成しました。")
    end

    it "passes an empty changes hash when every change input is blank or unsupported" do
      sign_in_as(admin_user)
      document = create(:document)
      dry_run = create(:bulk_edit_dry_run, created_by: admin_user, target_document_ids: [document.id])
      preview_service = double("DocumentBulkEditPreview", call: double(bulk_edit_dry_run: dry_run))

      expect(preview_class).to receive(:new).with(
        actor: admin_user,
        documents: contain_exactly(document),
        changes: {}
      ).and_return(preview_service)

      post admin_bulk_edit_dry_runs_path, params: {
        bulk_edit: {
          document_ids: [document.id],
          document_attributes: {
            category: "",
            visibility_policy: ""
          },
          latest_version_attributes: {
            snapshot_kind: "",
            published_from: ""
          },
          tag_changes: {
            add_tag_names: " ,、\n ",
            remove_tag_names: ""
          },
          archive_action: "delete"
        }
      }

      expect(response).to redirect_to(admin_bulk_edit_dry_run_path(dry_run))
    end

    it "does not create a dry-run when no documents are selected" do
      sign_in_as(admin_user)
      create(:document)

      expect(preview_class).not_to receive(:new)

      post admin_bulk_edit_dry_runs_path, params: {
        bulk_edit: {
          document_ids: ["", nil],
          document_attributes: {
            category: "manual"
          }
        }
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("一括編集対象の文書を選択してください。")
    end
  end

  describe "PATCH /admin/bulk_edit_dry_runs/:public_id" do
    it "executes the analyzed dry-run and redirects back to the result" do
      sign_in_as(admin_user)
      dry_run = create(:bulk_edit_dry_run, created_by: admin_user)
      executor = double("DocumentBulkEditExecutor", call: true)

      expect(executor_class).to receive(:new).with(dry_run: dry_run, actor: admin_user).and_return(executor)

      patch admin_bulk_edit_dry_run_path(dry_run)

      expect(response).to redirect_to(admin_bulk_edit_dry_run_path(dry_run))
      expect(flash[:notice]).to eq("一括編集を実行しました。")
    end

    it "redirects back with the executor error when execution is rejected" do
      sign_in_as(admin_user)
      dry_run = create(:bulk_edit_dry_run, created_by: admin_user)
      executor = double("DocumentBulkEditExecutor")

      expect(executor_class).to receive(:new).with(dry_run: dry_run, actor: admin_user).and_return(executor)
      expect(executor).to receive(:call).and_raise(ApplicationError::BadRequest, "bulk edit dry-run is expired")

      patch admin_bulk_edit_dry_run_path(dry_run)

      expect(response).to redirect_to(admin_bulk_edit_dry_run_path(dry_run))
      expect(flash[:alert]).to eq("bulk edit dry-run is expired")
    end
  end
end
