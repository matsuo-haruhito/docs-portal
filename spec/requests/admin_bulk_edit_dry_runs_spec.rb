require "rails_helper"

RSpec.describe "Admin bulk edit dry-runs", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:project) { create(:project, name: "Alpha Project") }
  let!(:document) { create(:document, project:, title: "Target Doc", category: :spec, visibility_policy: :restricted_external) }

  before do
    version = create(:document_version, document:, snapshot_kind: "current")
    document.update!(latest_version: version)
  end

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def parsed_json
    JSON.parse(response.body)
  end

  def checked_document_ids
    parsed_html.css(%(input[name="bulk_edit[document_ids][]"][checked])).map { |input| input["value"].to_i }
  end

  def hidden_candidate_document_ids
    parsed_html.css(%(input[type="hidden"][name="candidate_document_ids[]"])).map { |input| input["value"].to_i }
  end

  def hidden_source_filter_summaries
    parsed_html.css(%(input[type="hidden"][name="source_filter_summaries[]"])).map { |input| input["value"] }
  end

  def source_filter_badges
    parsed_html.xpath("//p[contains(concat(' ', normalize-space(@class), ' '), ' muted ')][contains(normalize-space(.), '代表条件:')]//span[contains(concat(' ', normalize-space(@class), ' '), ' badge ')]").map { |badge| badge.text.squish }
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
    expect(response.body).to include("選択状態JSONを確認")
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

  it "preselects valid document candidates passed from the document master list" do
    other_document = create(:document, project:, title: "Other Doc")

    sign_in_as(admin)

    get new_admin_bulk_edit_dry_run_path, params: {
      source: "admin_documents",
      candidate_document_ids: [document.id, 999_999, "invalid"],
      source_filter_summaries: ["キーワード: Alpha Project"]
    }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("文書マスタ一覧から引き継いだ初期候補: 1件")
    expect(page_text).to include("代表条件: キーワード: Alpha Project")
    expect(page_text).to include("候補文書は選択済みです")
    expect(page_text).to include("1件選択中")
    expect(page_text).to include("1件表示中")
    expect(page_text).to include("Target Doc")
    expect(page_text).not_to include("Other Doc")
    expect(checked_document_ids).to eq([document.id])
    expect(other_document).to be_persisted
  end

  it "limits and normalizes document candidates passed from the document master list" do
    candidate_documents = create_list(:document, 49, project:) do |candidate, index|
      candidate.update!(title: format("Candidate %02d", index + 1))
    end
    overflow_document = create(:document, project:, title: "Overflow Candidate")
    all_candidate_ids = [document.id, document.id, "invalid", *candidate_documents.map(&:id), overflow_document.id]
    expected_candidate_ids = [document.id, *candidate_documents.map(&:id)]
    long_summary = "X" * 81
    truncated_summary = "#{'X' * 77}..."
    visible_summaries = [
      truncated_summary,
      "分類: 仕様",
      "種別: Markdown",
      "公開範囲: 内部",
      "状態: 有効",
      "期限: 未設定",
      "廃棄: 未設定"
    ]

    sign_in_as(admin)

    get new_admin_bulk_edit_dry_run_path, params: {
      source: "admin_documents",
      candidate_document_ids: all_candidate_ids,
      source_filter_summaries: [" ", long_summary, *visible_summaries.drop(1), "8件目: 表示しない"]
    }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("文書マスタ一覧から引き継いだ初期候補: 50件")
    expect(page_text).to include("50件選択中")
    expect(page_text).to include("50件表示中")
    expect(checked_document_ids).to contain_exactly(*expected_candidate_ids)
    expect(hidden_candidate_document_ids).to eq(expected_candidate_ids)
    expect(source_filter_badges).to eq(visible_summaries)
    expect(hidden_source_filter_summaries).to eq(visible_summaries)
    expect(page_text).not_to include("Overflow Candidate")
    expect(response.body).not_to include(%(value="#{overflow_document.id}"))
    expect(response.body).not_to include(long_summary)
    expect(response.body).not_to include("8件目: 表示しない")
  end

  it "returns selected document state as read-only handoff JSON" do
    other_document = create(:document, project:, title: "Other Doc")
    long_summary = "Y" * 81
    truncated_summary = "#{'Y' * 77}..."

    sign_in_as(admin)

    dry_run_count = BulkEditDryRun.count
    access_log_count = AccessLog.count

    post handoff_admin_bulk_edit_dry_runs_path, params: {
      source: "admin_documents",
      candidate_document_ids: [document.id, other_document.id, 999_999, "invalid"],
      source_filter_summaries: [long_summary, "状態: 有効"],
      bulk_edit: {
        document_ids: [document.id, document.id, other_document.id, 999_999, "invalid"],
        document_attributes: {
          category: "manual"
        }
      }
    }

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/json")
    expect(BulkEditDryRun.count).to eq(dry_run_count)
    expect(AccessLog.count).to eq(access_log_count)

    json = parsed_json
    expect(json).to include(
      "source" => "admin_documents",
      "runbook_path" => "docs/文書マスタ運用runbook.md",
      "limit" => 50,
      "candidate_count" => 3,
      "requested_selected_count" => 3,
      "selected_count" => 2,
      "unresolved_selected_count" => 1,
      "truncated" => false,
      "source_filter_summaries" => [truncated_summary, "状態: 有効"]
    )
    expect(json["generated_at"]).to be_present
    expect(json["documents"].map { |entry| entry["title"] }).to eq(["Target Doc", "Other Doc"])
    expect(json["documents"].first).to include(
      "id" => document.id,
      "public_id" => document.public_id,
      "project" => { "code" => project.code, "name" => "Alpha Project" },
      "title" => "Target Doc",
      "status" => "active"
    )
    expect(response.body).not_to include("manual")
    expect(response.body).not_to include("invalid")
    expect(response.body).not_to include("999999")
    expect(response.body).not_to include(long_summary)
  end

  it "bounds handoff JSON to the candidate limit without broadening selection" do
    candidate_documents = create_list(:document, 50, project:) do |candidate, index|
      candidate.update!(title: format("Handoff Candidate %02d", index + 1))
    end
    selected_ids = [document.id, *candidate_documents.map(&:id)]

    sign_in_as(admin)

    post handoff_admin_bulk_edit_dry_runs_path, params: {
      bulk_edit: {
        document_ids: selected_ids
      }
    }

    expect(response).to have_http_status(:ok)
    json = parsed_json
    expect(json["source"]).to eq("direct_selection")
    expect(json["requested_selected_count"]).to eq(51)
    expect(json["selected_count"]).to eq(50)
    expect(json["limit"]).to eq(50)
    expect(json["truncated"]).to eq(true)
    expect(json["documents"].map { |entry| entry["title"] }).to include("Target Doc", "Handoff Candidate 49")
    expect(json["documents"].map { |entry| entry["title"] }).not_to include("Handoff Candidate 50")
  end

  it "returns an empty read-only handoff JSON without creating a dry-run" do
    sign_in_as(admin)

    expect do
      post handoff_admin_bulk_edit_dry_runs_path, params: {
        bulk_edit: {
          document_ids: []
        }
      }
    end.not_to change(BulkEditDryRun, :count)

    expect(response).to have_http_status(:ok)
    expect(parsed_json).to include(
      "source" => "direct_selection",
      "candidate_count" => 0,
      "requested_selected_count" => 0,
      "selected_count" => 0,
      "unresolved_selected_count" => 0,
      "truncated" => false,
      "documents" => []
    )
  end

  it "handles empty or invalid document candidates without broadening the bulk edit list" do
    sign_in_as(admin)

    get new_admin_bulk_edit_dry_run_path, params: {
      source: "admin_documents",
      candidate_document_ids: ["missing"]
    }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("文書マスタ一覧から引き継いだ初期候補: 0件")
    expect(page_text).to include("有効な候補文書がありません")
    expect(page_text).to include("0件選択中")
    expect(page_text).to include("0件表示中")
    expect(page_text).not_to include("Target Doc")
    expect(checked_document_ids).to be_empty
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
          total_count: 4,
          changed_count: 2
        }
      },
      result_json: {
        preview_items: [
          preview_item("Warning Doc", changed_fields: ["category"], warnings: ["分類が未確認です"]),
          preview_item("Error Doc", changed_fields: ["visibility_policy"], errors: ["公開範囲を解決できません"]),
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
    expect(page_text).to include("警告 / エラー")
    expect(page_text).to include("1 / 1")
    expect(page_text).to include("警告・エラーのある行を先に確認")
    expect(parsed_html.at_css('a[href="#bulk-edit-review-details"]')&.text).to include("事前確認明細へ移動")
    expect(parsed_html.at_css("#bulk-edit-review-details")).to be_present
    expect(page_text).to include("確認優先サマリ: エラーあり: 1件 / 警告あり: 1件 / 変更予定: 1件 / 変更なし: 1件")
    expect(page_text).to include("確認目安")
    expect(page_text).to include("確認目安は表示補助です")
    expect(page_text).to include("分類が未確認の文書があります")
    expect(page_text).to include("公開範囲を解決できない文書があります")
    expect(response.body).to include("bulk-edit-review-row--warning")
    expect(response.body).to include("bulk-edit-review-row--error")
    expect(response.body).to include("bulk-edit-review-row--changed")
    expect(response.body).to include("bulk-edit-review-row--unchanged")

    warning_row, error_row, changed_row, clean_row = preview_rows
    expect(warning_row).to include("Warning Doc", "警告あり", "分類", "分類が未確認です", "-")
    expect(error_row).to include("Error Doc", "エラーあり", "公開範囲", "-", "公開範囲を解決できません")
    expect(changed_row).to include("Changed Doc", "変更予定")
    expect(clean_row).to include("Clean Doc", "変更なし", "-", "-", "-")
  end

  it "previews dry-run diagnostics without exposing sensitive raw fragments" do
    sign_in_as(admin)
    long_suffix = "x" * 160
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
        },
        execution: {
          total_count: 1,
          success_count: 0,
          failure_count: 1,
          skipped_count: 0
        }
      },
      result_json: {
        preview_items: [
          preview_item(
            "Sensitive Doc",
            changed_fields: ["category"],
            warnings: ["refresh_token=preview-refresh-token path /home/alice/docs/#{long_suffix}"],
            errors: ["password=preview-password-value path C:/Users/Alice/private/#{long_suffix}"]
          )
        ],
        execution_items: [
          execution_item(
            "Failed Sensitive Doc",
            status: "failed",
            changed_fields: ["category"],
            warnings: ["token=execution-token-value #{long_suffix}"],
            errors: ["Bearer execution-bearer-token #{long_suffix}"]
          )
        ]
      },
      warnings_json: ["Authorization: Bearer bulk-edit-token-12345 failed at /Users/alice/customer/#{long_suffix}"],
      errors_json: ["client_secret=bulk-client-secret-value failed at C:/Users/Alice/customer/#{long_suffix}"],
      status: :confirmed,
      confirmed_by: admin,
      confirmed_at: Time.current,
      expires_at: 1.day.from_now
    )

    get admin_bulk_edit_dry_run_path(dry_run)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("1 / 1")
    expect(page_text).to include("Sensitive Doc")
    expect(page_text).to include("Failed Sensitive Doc")
    expect(page_text).to include("Authorization: [masked]")
    expect(page_text).to include("client_secret=[masked]")
    expect(page_text).to include("refresh_token=[masked]")
    expect(page_text).to include("password=[masked]")
    expect(page_text).to include("token=[masked]")
    expect(page_text).to include("Bearer [masked]")
    expect(page_text).to include("[path hidden]")
    expect(page_text).to include("...")

    expect(response.body).not_to include("bulk-edit-token-12345")
    expect(response.body).not_to include("bulk-client-secret-value")
    expect(response.body).not_to include("preview-refresh-token")
    expect(response.body).not_to include("preview-password-value")
    expect(response.body).not_to include("execution-token-value")
    expect(response.body).not_to include("execution-bearer-token")
    expect(response.body).not_to include("/Users/alice/customer")
    expect(response.body).not_to include("/home/alice/docs")
    expect(response.body).not_to include("C:/Users/Alice")

    expect(preview_rows.first.join(" ")).to include("エラーあり", "[masked]", "[path hidden]")
    expect(execution_rows.first.join(" ")).to include("Failed Sensitive Doc", "[masked]")
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

  it "forbids external users from handoff JSON" do
    sign_in_as(create(:user, :external))

    post handoff_admin_bulk_edit_dry_runs_path, params: {
      bulk_edit: {
        document_ids: [document.id]
      }
    }

    expect(response).to have_http_status(:forbidden)
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
