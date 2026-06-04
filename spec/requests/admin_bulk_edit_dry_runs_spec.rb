require "rails_helper"

RSpec.describe "Admin bulk edit dry-runs", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:project) { create(:project, name: "Alpha Project") }
  let!(:document) { create(:document, project:, title: "Target Doc", category: :spec, visibility_policy: :restricted_external) }

  before do
    version = create(:document_version, document:, snapshot_kind: "current")
    document.update!(latest_version: version)
  end

  it "creates a dry-run and then executes the confirmed bulk edit" do
    sign_in_as(admin)

    get new_admin_bulk_edit_dry_run_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("文書一括編集")
    expect(response.body).to include("Target Doc")
    expect(response.body).to include("0件選択中")
    expect(response.body).to include("1件表示中")
    expect(response.body).to include("対象を検索")
    expect(response.body).to include("選択済みだけ表示")
    expect(response.body).to include("実行は次の確認画面で行います")
    expect(response.body).to include("data-controller=\"bulk-edit-selection\"")
    expect(response.body).to include("data-bulk-edit-selection-search-text")

    expect do
      post admin_bulk_edit_dry_runs_path, params: {
        bulk_edit: {
          document_ids: [document.id],
          document_attributes: {
            category: "manual",
            visibility_policy: "public_with_login",
            importance_level: "critical"
          },
          latest_version_attributes: {
            snapshot_kind: "submitted"
          },
          tag_changes: {
            add_tag_names: "重要, 社外"
          }
        }
      }
    end.to change(BulkEditDryRun, :count).by(1)

    dry_run = BulkEditDryRun.last
    expect(response).to redirect_to(admin_bulk_edit_dry_run_path(dry_run))
    follow_redirect!
    expect(response.body).to include("事前確認ID")
    expect(response.body).to include("公開範囲")
    expect(response.body).to include("確認して実行")

    expect do
      patch admin_bulk_edit_dry_run_path(dry_run)
    end.to change(AccessLog.bulk_edit, :count).by(1)

    expect(response).to redirect_to(admin_bulk_edit_dry_run_path(dry_run))
    expect(document.reload.category).to eq("manual")
    expect(document.visibility_policy).to eq("public_with_login")
    expect(document.importance_level).to eq("critical")
    expect(document.latest_version.reload.snapshot_kind).to eq("submitted")
    expect(document.document_tags.pluck(:name)).to contain_exactly("重要", "社外")
    expect(dry_run.reload).to be_confirmed
  end

  it "shows review cues for warning, error, changed, and unchanged preview rows" do
    sign_in_as(admin)
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
          total_count: 4,
          changed_count: 2
        }
      },
      result_json: {
        preview_items: [
          preview_item("Error Doc", changed_fields: ["visibility_policy"], errors: ["公開範囲を解決できません"]),
          preview_item("Warning Doc", changed_fields: ["category"], warnings: ["分類が未確認です"]),
          preview_item("Changed Doc", changed_fields: ["importance_level"]),
          preview_item("Clean Doc", changed_fields: [])
        ]
      },
      warnings_json: ["分類が未確認の文書があります"],
      errors_json: ["公開範囲を解決できない文書があります"],
      status: :analyzed,
      expires_at: 1.day.from_now
    )

    get admin_bulk_edit_dry_run_path(dry_run)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("警告・エラーのある行を先に確認")
    expect(response.body).to include("確認目安")
    expect(response.body).to include("確認目安は表示補助です")
    expect(response.body).to include("エラーあり")
    expect(response.body).to include("警告あり")
    expect(response.body).to include("変更予定")
    expect(response.body).to include("変更なし")
    expect(response.body).to include("bulk-edit-review-row--error")
    expect(response.body).to include("bulk-edit-review-row--warning")
    expect(response.body).to include("bulk-edit-review-row--changed")
    expect(response.body).to include("bulk-edit-review-row--unchanged")
    expect(response.body).to include("公開範囲を解決できません")
    expect(response.body).to include("分類が未確認です")
  end

  it "rejects dry-run creation without selected documents" do
    sign_in_as(admin)

    post admin_bulk_edit_dry_runs_path, params: {
      bulk_edit: {
        document_attributes: { category: "manual" }
      }
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("一括編集対象の文書を選択してください")
  end

  it "forbids external users" do
    sign_in_as(create(:user, :external))

    get new_admin_bulk_edit_dry_run_path

    expect(response).to have_http_status(:forbidden)
  end

  def preview_item(title, changed_fields:, warnings: [], errors: [])
    {
      document_id: document.id,
      document_public_id: document.public_id,
      before: {
        document: {
          title:,
          category: "spec",
          document_kind: "markdown",
          visibility_policy: "restricted_external",
          importance_level: "normal",
          archived: false
        },
        latest_version: {
          snapshot_kind: "current"
        },
        tag_names: []
      },
      after: {
        document: {
          title:,
          category: changed_fields.include?("category") ? "manual" : "spec",
          document_kind: "markdown",
          visibility_policy: changed_fields.include?("visibility_policy") ? "public_with_login" : "restricted_external",
          importance_level: changed_fields.include?("importance_level") ? "critical" : "normal",
          archived: false
        },
        latest_version: {
          snapshot_kind: "current"
        },
        tag_names: []
      },
      changed_fields:,
      warnings:,
      errors:
    }
  end
end
