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

  it "shows warning, error, and fallback values on the dry-run preview" do
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
          total_count: 3,
          changed_count: 1
        }
      },
      result_json: {
        preview_items: [
          preview_item("Warning Doc", changed_fields: ["category"], warnings: ["分類が未確認です"]),
          preview_item("Error Doc", changed_fields: ["visibility_policy"], errors: ["公開範囲を解決できません"]),
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
    expect(page_text).to include("警告 / エラー")
    expect(page_text).to include("1 / 1")
    expect(page_text).to include("分類が未確認の文書があります")
    expect(page_text).to include("公開範囲を解決できない文書があります")

    warning_row, error_row, clean_row = preview_rows
    expect(warning_row).to include("Warning Doc", "分類", "分類が未確認です", "-")
    expect(error_row).to include("Error Doc", "公開範囲", "-", "公開範囲を解決できません")
    expect(clean_row).to include("Clean Doc", "-", "-", "-")
  end

  it "shows success, failure, skipped, and fallback values on execution results" do
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
          total_count: 3,
          changed_count: 1
        },
        execution: {
          total_count: 3,
          success_count: 1,
          failure_count: 1,
          skipped_count: 1
        }
      },
      result_json: {
        preview_items: [],
        execution_items: [
          execution_item("Success Doc", status: "success", changed_fields: ["category"]),
          execution_item("Failed Doc", status: "failed", changed_fields: ["visibility_policy"], errors: ["保存に失敗しました"]),
          execution_item("Skipped Doc", status: "skipped", changed_fields: [], warnings: ["変更なしのためスキップ"])
        ]
      },
      warnings_json: [],
      errors_json: [],
      status: :confirmed,
      confirmed_by: admin,
      confirmed_at: Time.current,
      expires_at: 1.day.from_now
    )

    get admin_bulk_edit_dry_run_path(dry_run)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("実行結果")
    expect(page_text).to include("個別文書ごとの成功/失敗を表示します。")

    success_row, failed_row, skipped_row = execution_rows
    expect(success_row).to include("Success Doc", "分類", "-", "-")
    expect(failed_row).to include("Failed Doc", "公開範囲", "-", "保存に失敗しました")
    expect(skipped_row).to include("Skipped Doc", "-", "変更なしのためスキップ", "-")
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

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def preview_rows
    rows_for_section("事前確認明細")
  end

  def execution_rows
    rows_for_section("実行結果")
  end

  def rows_for_section(title)
    section = parsed_html.at_xpath("//section[contains(concat(' ', normalize-space(@class), ' '), ' card ')][.//h2[normalize-space()='#{title}']]")
    expect(section).to be_present

    section.css("tbody tr").map do |row|
      row.css("td").map { |cell| cell.text.squish }
    end
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
          category: changed_fields.include?("category") ? "manual" : "spec",
          document_kind: "markdown",
          visibility_policy: changed_fields.include?("visibility_policy") ? "public_with_login" : "restricted_external",
          importance_level: "normal",
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

  def execution_item(title, status:, changed_fields:, warnings: [], errors: [])
    {
      document_id: document.id,
      document_public_id: document.public_id,
      title:,
      status:,
      changed_fields:,
      warnings:,
      errors:
    }
  end
end