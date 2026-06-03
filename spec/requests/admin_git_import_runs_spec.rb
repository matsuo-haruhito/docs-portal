require "rails_helper"

RSpec.describe "Admin git import runs", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:external_user) { create(:user, :external) }
  let(:project) { create(:project, code: "GIT", name: "Git Import Project") }
  let(:git_import_source) { create(:git_import_source, project:) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def run_rows
    parsed_html.css("table tbody tr")
  end

  def create_git_import_run!(git_import_source: self.git_import_source, repository_full_name: git_import_source.repository_full_name, created_at: Time.zone.parse("2026-05-01 00:00:00 UTC"), status: :imported, summary_json: { imported: 1 }, error_message: nil)
    GitImportRun.create!(
      git_import_source:,
      repository_full_name:,
      branch: git_import_source.branch,
      source_path: git_import_source.source_path,
      provider: :github,
      import_mode: :pull,
      status:,
      commit_sha: "abcdef1234567890",
      summary_json:,
      error_message:,
      created_at:,
      updated_at: created_at
    )
  end

  it "shows an empty state when no runs exist yet" do
    sign_in_as(admin_user)

    get admin_git_import_runs_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("まだGit同期履歴はありません。")
    expect(page_text).to include("Git連携 で案件、リポジトリ、ブランチ、取込元パスを設定し、「手動同期」を実行すると、ここに履歴が表示されます。")
    expect(page_text).to include("この画面では、同期結果やエラー内容をあとから確認できます。")
    expect(response.body).not_to include("Git同期履歴の表示設定")
    expect(response.body).not_to include('data-rails-table-preferences-column-key="created_at"')
  end

  it "shows git import history when runs exist" do
    create_git_import_run!

    sign_in_as(admin_user)

    get admin_git_import_runs_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Git同期履歴")
    expect(response.body).to include("Git Import Project")
    expect(response.body).to include(git_import_source.repository_full_name)
    expect(page_text).to include("表示中: 1件 / 条件に一致する最新100件までを表示")
    expect(response.body).to include("Git同期履歴の表示設定")
    expect(run_rows.size).to eq(1)
  end

  it "filters git import history by status" do
    create_git_import_run!(repository_full_name: "matsuo-haruhito/docs-portal", status: :imported)
    create_git_import_run!(repository_full_name: "matsuo-haruhito/failing-docs", status: :failed, error_message: "repository not found", created_at: Time.zone.parse("2026-05-02 00:00:00 UTC"))

    sign_in_as(admin_user)

    get admin_git_import_runs_path(status: "failed")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("有効な条件: 状態: failed")
    expect(page_text).to include("表示中: 1件 / 条件に一致する最新100件までを表示")
    expect(response.body).to include("matsuo-haruhito/failing-docs")
    expect(response.body).not_to include("matsuo-haruhito/docs-portal")
    expect(run_rows.size).to eq(1)
  end

  it "ignores unknown status filters without returning an error" do
    create_git_import_run!(repository_full_name: "matsuo-haruhito/docs-portal", status: :imported)

    sign_in_as(admin_user)

    get admin_git_import_runs_path(status: "unknown")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("matsuo-haruhito/docs-portal")
    expect(page_text).not_to include("状態: unknown")
    expect(run_rows.size).to eq(1)
  end

  it "filters git import history by repository fragment" do
    create_git_import_run!(repository_full_name: "matsuo-haruhito/docs-portal")
    create_git_import_run!(repository_full_name: "matsuo-haruhito/internal-notes", created_at: Time.zone.parse("2026-05-02 00:00:00 UTC"))

    sign_in_as(admin_user)

    get admin_git_import_runs_path(repository_q: "docs")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("有効な条件: リポジトリ: docs")
    expect(response.body).to include("matsuo-haruhito/docs-portal")
    expect(response.body).not_to include("matsuo-haruhito/internal-notes")
    expect(run_rows.size).to eq(1)
  end

  it "combines status and repository filters and keeps table preferences visible" do
    create_git_import_run!(repository_full_name: "matsuo-haruhito/docs-portal", status: :failed, error_message: "repository not found")
    create_git_import_run!(repository_full_name: "matsuo-haruhito/docs-portal", status: :imported, created_at: Time.zone.parse("2026-05-02 00:00:00 UTC"))
    create_git_import_run!(repository_full_name: "matsuo-haruhito/internal-notes", status: :failed, created_at: Time.zone.parse("2026-05-03 00:00:00 UTC"))

    sign_in_as(admin_user)

    get admin_git_import_runs_path(status: "failed", repository_q: "docs-portal")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("状態: failed")
    expect(page_text).to include("リポジトリ: docs-portal")
    expect(response.body).to include("matsuo-haruhito/docs-portal")
    expect(response.body).not_to include("matsuo-haruhito/internal-notes")
    expect(response.body).to include("Git同期履歴の表示設定")
    expect(response.body).to include('data-rails-table-preferences-column-key="repository"')
    expect(run_rows.size).to eq(1)
  end

  it "shows a filtered empty state with a clear link" do
    create_git_import_run!(repository_full_name: "matsuo-haruhito/docs-portal")

    sign_in_as(admin_user)

    get admin_git_import_runs_path(repository_q: "missing")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示中: 0件 / 条件に一致する最新100件までを表示")
    expect(page_text).to include("条件に一致するGit同期履歴はありません。")
    expect(response.body).to include("条件をクリア")
    expect(response.body).not_to include("まだGit同期履歴はありません。")
    expect(response.body).not_to include("Git同期履歴の表示設定")
  end

  it "limits the filtered result to the latest 100 rows after filtering" do
    101.times do |index|
      create_git_import_run!(
        repository_full_name: "matsuo-haruhito/docs-portal",
        created_at: Time.zone.parse("2026-05-01 00:00:00 UTC") + index.minutes,
        status: :failed,
        error_message: "failure #{index}"
      )
    end
    create_git_import_run!(
      repository_full_name: "matsuo-haruhito/internal-notes",
      created_at: Time.zone.parse("2026-06-01 00:00:00 UTC"),
      status: :failed,
      error_message: "newer unrelated failure"
    )

    sign_in_as(admin_user)

    get admin_git_import_runs_path(status: "failed", repository_q: "docs-portal")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示中: 100件 / 条件に一致する最新100件までを表示")
    expect(run_rows.size).to eq(100)
    expect(response.body).to include("failure 100")
    expect(response.body).not_to include("failure 0")
    expect(response.body).not_to include("newer unrelated failure")
  end

  it "summarizes imported, skipped, failed, and deleted candidate context" do
    create_git_import_run!(
      summary_json: {
        "documents" => 3,
        "attachments" => 5,
        "source_path" => "docs",
        "commit_sha" => "abcdef1234567890",
        "deleted_candidates" => ["docs/old.md"],
        "publish_job_id" => "pub_123"
      }
    )
    create_git_import_run!(
      status: :skipped,
      summary_json: { "reason" => "already_synced", "commit_sha" => "abcdef1234567890" },
      created_at: Time.zone.parse("2026-05-02 00:00:00 UTC")
    )
    create_git_import_run!(
      status: :failed,
      summary_json: {},
      error_message: "repository not found",
      created_at: Time.zone.parse("2026-05-03 00:00:00 UTC")
    )

    sign_in_as(admin_user)

    get admin_git_import_runs_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("provider、pull/push、status、summary_json、削除候補を追跡します")
    expect(page_text).to include("取り込み文書: 3")
    expect(page_text).to include("添付: 5")
    expect(page_text).to include("取込元パス: docs")
    expect(page_text).to include("commit: abcdef1234567890")
    expect(page_text).to include("削除候補: 1")
    expect(page_text).to include("PublishJob: pub_123")
    expect(page_text).to include("理由: already_synced")
    expect(page_text).to include("repository not found")
    expect(page_text).to include("raw summary_json")
  end

  it "forbids external users" do
    sign_in_as(external_user)

    get admin_git_import_runs_path

    expect(response).to have_http_status(:forbidden)
  end
end
