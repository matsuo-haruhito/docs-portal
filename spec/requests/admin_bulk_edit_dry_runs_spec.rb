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

  def checked_document_ids
    parsed_html.css(%(input[name="bulk_edit[document_ids][]"][checked])).map { |input| input["value"].to_i }
  end

  it "creates a dry-run and then executes the confirmed bulk edit" do
    sign_in_as(admin)

    get new_admin_bulk_edit_dry_run_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("文書一括編集")
    expect(response.body).to include("Target Doc")

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
    expect(page_text).to include("文書マスタ一覧から引き継いだ候補: 1件")
    expect(page_text).to include("代表条件: キーワード: Alpha Project")
    expect(page_text).to include("候補文書は選択済みです")
    expect(page_text).to include("Target Doc")
    expect(page_text).not_to include("Other Doc")
    expect(checked_document_ids).to eq([document.id])
    expect(other_document).to be_persisted
  end

  it "handles empty or invalid document candidates without broadening the bulk edit list" do
    sign_in_as(admin)

    get new_admin_bulk_edit_dry_run_path, params: {
      source: "admin_documents",
      candidate_document_ids: ["missing"]
    }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("文書マスタ一覧から引き継いだ候補: 0件")
    expect(page_text).to include("有効な候補文書がありません")
    expect(page_text).not_to include("Target Doc")
    expect(checked_document_ids).to be_empty
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
end
