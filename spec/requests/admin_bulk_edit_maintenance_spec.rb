require "rails_helper"

RSpec.describe "Admin bulk edit maintenance mode", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:project) { create(:project, name: "Bulk Maintenance Project") }
  let!(:document) { create(:document, project:, title: "Bulk Maintenance Doc", category: :spec, visibility_policy: :restricted_external) }

  around do |example|
    previous = ENV.fetch(Admin::BulkEditDryRunsController::READ_ONLY_MAINTENANCE_ENV, nil)
    ENV[Admin::BulkEditDryRunsController::READ_ONLY_MAINTENANCE_ENV] = maintenance_value
    example.run
  ensure
    if previous.nil?
      ENV.delete(Admin::BulkEditDryRunsController::READ_ONLY_MAINTENANCE_ENV)
    else
      ENV[Admin::BulkEditDryRunsController::READ_ONLY_MAINTENANCE_ENV] = previous
    end
  end

  before do
    version = create(:document_version, document:, snapshot_kind: "current")
    document.update!(latest_version: version)
  end

  describe "when read-only maintenance is enabled" do
    let(:maintenance_value) { "1" }

    it "does not create a new dry-run" do
      sign_in_as(admin)

      expect do
        post admin_bulk_edit_dry_runs_path, params: {
          bulk_edit: {
            document_ids: [document.id],
            document_attributes: {
              category: "manual",
              visibility_policy: "public_with_login"
            }
          }
        }
      end.not_to change(BulkEditDryRun, :count)

      expect(response).to redirect_to(new_admin_bulk_edit_dry_run_path)
      expect(flash[:alert]).to include("メンテナンス中のため文書一括編集dry-runの作成と実行は停止しています")
      expect(document.reload.category).to eq("spec")
      expect(document.visibility_policy).to eq("restricted_external")
    end

    it "keeps selected document handoff JSON read-only" do
      sign_in_as(admin)

      expect do
        post handoff_admin_bulk_edit_dry_runs_path, params: {
          source: "admin_documents",
          candidate_document_ids: [document.id],
          source_filter_summaries: ["キーワード: Bulk"],
          bulk_edit: {
            document_ids: [document.id],
            document_attributes: {
              category: "manual"
            }
          }
        }
      end.not_to change(BulkEditDryRun, :count)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/json")

      json = JSON.parse(response.body)
      expect(json).to include(
        "source" => "admin_documents",
        "runbook_path" => "docs/文書マスタ運用runbook.md",
        "candidate_count" => 1,
        "requested_selected_count" => 1,
        "selected_count" => 1,
        "truncated" => false,
        "source_filter_summaries" => ["キーワード: Bulk"]
      )
      expect(json.fetch("documents").first).to include(
        "public_id" => document.public_id,
        "title" => "Bulk Maintenance Doc",
        "status" => "active"
      )
      expect(response.body).not_to include("manual")
    end

    it "keeps existing dry-run detail readable but does not execute it" do
      dry_run = BulkEditDryRun.create!(
        project:,
        created_by: admin,
        operation_type: :document_metadata,
        target_document_ids: [document.id],
        params_json: {
          document_attributes: {
            category: "manual"
          }
        },
        summary_json: {
          preview: {
            total_count: 1,
            changed_count: 1
          }
        },
        result_json: {
          preview_items: []
        },
        warnings_json: [],
        errors_json: [],
        status: :analyzed,
        expires_at: 1.day.from_now
      )
      sign_in_as(admin)

      get admin_bulk_edit_dry_run_path(dry_run)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(dry_run.public_id)

      expect do
        patch admin_bulk_edit_dry_run_path(dry_run)
      end.not_to change(AccessLog.bulk_edit, :count)

      expect(response).to redirect_to(admin_bulk_edit_dry_run_path(dry_run))
      expect(flash[:alert]).to include("メンテナンス中のため文書一括編集dry-runの作成と実行は停止しています")
      expect(document.reload.category).to eq("spec")
      expect(dry_run.reload).to be_analyzed
      expect(dry_run.confirmed_at).to be_nil
      expect(dry_run.confirmed_by).to be_nil
    end
  end

  describe "when read-only maintenance is disabled" do
    let(:maintenance_value) { "0" }

    it "keeps dry-run creation available" do
      sign_in_as(admin)

      expect do
        post admin_bulk_edit_dry_runs_path, params: {
          bulk_edit: {
            document_ids: [document.id],
            document_attributes: {
              category: "manual"
            }
          }
        }
      end.to change(BulkEditDryRun, :count).by(1)

      expect(response).to redirect_to(admin_bulk_edit_dry_run_path(BulkEditDryRun.last))
      expect(BulkEditDryRun.last).to be_analyzed
    end
  end
end
