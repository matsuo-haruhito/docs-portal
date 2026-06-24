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

  def filtered_empty_state_card
    parsed_html.xpath("//div[contains(concat(' ', normalize-space(@class), ' '), ' card ')][.//p[contains(normalize-space(.), '条件に一致するGit同期履歴はありません。')]]").first
  end

  def create_git_import_run!(git_import_source: self.git_import_source, created_at: Time.zone.parse("2026-05-01 00:00:00 UTC"), status: :imported, summary_json: { imported: 1 }, error_message: nil, commit_sha: "abcdef1234567890")
    GitImportRun.create!(
      git_import_source:,
      repository_full_name: git_import_source.repository_full_name,
      branch: git_import_source.branch,
      source_path: git_import_source.source_path,
      provider: :github,
      import_mode: :pull,
      status:,
      commit_sha:,
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
    expect(filtered_empty_state_card).to be_nil
  end

  it "shows git import history when runs exist" do
    create_git_import_run!

    sign_in_as(admin_user)

    get admin_git_import_runs_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Git同期履歴")
    expect(response.body).to include("Git Import Project")
    expect(response.body).to include(git_import_source.repository_full_name)
    expect(page_text).to include("表示中: 1件 / 最新100件までを表示")
    expect(page_text).to include("表示中の最新100件内の状態: 取込済み: 1件")
    expect(page_text).not_to include("エラー列を確認してください")
    expect(page_text).not_to include("実行結果の理由を確認してください")
    expect(response.body).to include("Git同期履歴の表示設定")
    expect(run_rows.size).to eq(1)
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
    expect(page_text).to include("表示中の最新100件内の状態: 失敗: 1件 / スキップ: 1件 / 取込済み: 1件")
    expect(page_text).to include("失敗 1件はエラー列を確認してください。")
    expect(page_text).to include("スキップ 1件は実行結果の理由を確認してください。")
    expect(page_text).to include("取り込み文書: 3")
    expect(page_text).to include("添付: 5")
    expect(page_text).to include("取込元パス: docs")
    expect(page_text).to include("commit: abcdef1234567890")
    expect(page_text).to include("削除候補: 1")
    expect(page_text).to include("PublishJob: pub_123")
    expect(page_text).to include("理由: already_synced")
    expect(page_text).to include("repository not found")
    expect(page_text).to include("summary_json のマスク済み詳細")
  end

  it "masks raw summary and error diagnostics while preserving operational context" do
    summary_token = "ghp_summary_sensitive_token"
    error_token = "ghp_error_sensitive_token"
    error_bearer = "error-bearer-token"
    private_windows_path = "C:/Users/alice/customer-docs/secrets.md"
    private_home_path = "/home/alice/.ssh/id_rsa"
    long_error_tail = "x" * 260

    create_git_import_run!(
      status: :failed,
      summary_json: {
        "documents" => 2,
        "source_path" => "docs",
        "commit_sha" => "abcdef1234567890",
        "provider_error" => "Authorization: Bearer #{summary_token}",
        "workspace_path" => private_windows_path,
        "credentials" => { "access_token" => "summary-access-token" }
      },
      error_message: "fatal token=#{error_token} Authorization: Bearer #{error_bearer} failed at #{private_home_path} #{long_error_tail}"
    )

    sign_in_as(admin_user)

    get admin_git_import_runs_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("取込元パス: docs")
    expect(page_text).to include("commit: abcdef1234567890")
    expect(page_text).to include("summary_json のマスク済み詳細")
    expect(page_text).to include("診断表示は secret-like value と private path を伏せた最大240文字程度のマスク済み preview です。完全な raw log ではありません。")
    expect(response.body).to include("[masked]")
    expect(response.body).to include("[path hidden]")
    expect(response.body).not_to include(summary_token)
    expect(response.body).not_to include("summary-access-token")
    expect(response.body).not_to include(error_token)
    expect(response.body).not_to include(error_bearer)
    expect(response.body).not_to include(private_windows_path)
    expect(response.body).not_to include(private_home_path)
    expect(response.body).not_to include(long_error_tail)
  end

  it "filters runs by status" do
    create_git_import_run!(status: :failed, error_message: "repository not found")
    create_git_import_run!(
      status: :imported,
      summary_json: { "reason" => "imported documents" },
      created_at: Time.zone.parse("2026-05-02 00:00:00 UTC")
    )

    sign_in_as(admin_user)

    get admin_git_import_runs_path, params: { status: "failed" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示中: 1件 / 絞り込み後の最新100件までを表示")
    expect(page_text).to include("表示中の最新100件内の状態: 失敗: 1件")
    expect(page_text).to include("失敗 1件はエラー列を確認してください。")
    expect(page_text).to include("repository not found")
    expect(page_text).to include("絞り込み解除")
    expect(response.body).to include("Git同期履歴の表示設定")
    expect(response.body).to include('data-rails-table-preferences-column-key="status"')
    expect(page_text).not_to include("imported documents")
    expect(run_rows.size).to eq(1)
  end

  it "filters runs by repository fragment" do
    docs_source = create(:git_import_source, project:, repository_full_name: "matsuo-haruhito/docs-portal")
    work_source = create(:git_import_source, project:, repository_full_name: "matsuo-haruhito/work-codex")
    create_git_import_run!(git_import_source: docs_source, summary_json: { "reason" => "docs hit" })
    create_git_import_run!(git_import_source: work_source, summary_json: { "reason" => "work miss" })

    sign_in_as(admin_user)

    get admin_git_import_runs_path, params: { repository: "DOCS-PORTAL" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示中: 1件 / 絞り込み後の最新100件までを表示")
    expect(page_text).to include("リポジトリ名は owner/repo の一部一致で検索します。")
    expect(page_text).to include("表示中の最新100件内の状態: 取込済み: 1件")
    expect(page_text).to include("matsuo-haruhito/docs-portal")
    expect(page_text).to include("docs hit")
    expect(page_text).not_to include("matsuo-haruhito/work-codex")
    expect(page_text).not_to include("work miss")
    expect(response.body).to include('value="DOCS-PORTAL"')
  end

  it "filters runs by branch fragment" do
    main_source = create(:git_import_source, project:, repository_full_name: "matsuo-haruhito/docs-main", branch: "main")
    release_source = create(:git_import_source, project:, repository_full_name: "matsuo-haruhito/docs-release", branch: "release/v1")
    create_git_import_run!(git_import_source: main_source, summary_json: { "reason" => "main branch hit" })
    create_git_import_run!(git_import_source: release_source, summary_json: { "reason" => "release branch miss" })

    sign_in_as(admin_user)

    get admin_git_import_runs_path, params: { branch: "MAIN" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示中: 1件 / 絞り込み後の最新100件までを表示")
    expect(page_text).to include("ブランチ名は一部一致で検索します。")
    expect(page_text).to include("main branch hit")
    expect(page_text).not_to include("release branch miss")
    expect(response.body).to include('value="MAIN"')
    expect(run_rows.size).to eq(1)
  end

  it "filters runs by source path fragment" do
    docs_source = create(:git_import_source, project:, repository_full_name: "matsuo-haruhito/docs-guides", source_path: "docs/guides")
    app_source = create(:git_import_source, project:, repository_full_name: "matsuo-haruhito/app-content", source_path: "app/content")
    create_git_import_run!(git_import_source: docs_source, summary_json: { "reason" => "guide path hit" })
    create_git_import_run!(git_import_source: app_source, summary_json: { "reason" => "app path miss" })

    sign_in_as(admin_user)

    get admin_git_import_runs_path, params: { source_path: "GUIDES" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("取込元パスは一部一致で検索します。")
    expect(page_text).to include("guide path hit")
    expect(page_text).not_to include("app path miss")
    expect(response.body).to include('value="GUIDES"')
    expect(run_rows.size).to eq(1)
  end

  it "filters runs by commit sha prefix" do
    create_git_import_run!(summary_json: { "reason" => "commit hit" }, commit_sha: "abcdef1234567890")
    create_git_import_run!(
      summary_json: { "reason" => "commit miss" },
      commit_sha: "123456abcdef7890",
      created_at: Time.zone.parse("2026-05-02 00:00:00 UTC")
    )

    sign_in_as(admin_user)

    get admin_git_import_runs_path, params: { commit_sha: "ABCDEF12" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("commit SHA は前方一致で検索します。結果は絞り込み後の最新100件までです。")
    expect(page_text).to include("commit hit")
    expect(page_text).not_to include("commit miss")
    expect(response.body).to include('value="ABCDEF12"')
    expect(run_rows.size).to eq(1)
  end

  it "combines status, repository, branch, source path, and commit filters" do
    target_source = create(:git_import_source, project:, repository_full_name: "matsuo-haruhito/docs-portal", branch: "release/v2", source_path: "docs/operations")
    other_branch_source = create(:git_import_source, project:, repository_full_name: "matsuo-haruhito/docs-portal", branch: "main", source_path: "docs/operations")
    other_path_source = create(:git_import_source, project:, repository_full_name: "matsuo-haruhito/docs-portal", branch: "release/v2", source_path: "docs/guides")
    create_git_import_run!(git_import_source: target_source, status: :failed, error_message: "target failure", commit_sha: "feedface12345678")
    create_git_import_run!(git_import_source: target_source, status: :imported, summary_json: { "reason" => "wrong status" }, commit_sha: "feedface12345678")
    create_git_import_run!(git_import_source: other_branch_source, status: :failed, error_message: "wrong branch", commit_sha: "feedface12345678")
    create_git_import_run!(git_import_source: other_path_source, status: :failed, error_message: "wrong path", commit_sha: "feedface12345678")

    sign_in_as(admin_user)

    get admin_git_import_runs_path, params: {
      status: "failed",
      repository: "docs-portal",
      branch: "release",
      source_path: "operations",
      commit_sha: "feedface"
    }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示中の最新100件内の状態: 失敗: 1件")
    expect(page_text).to include("target failure")
    expect(page_text).not_to include("wrong status")
    expect(page_text).not_to include("wrong branch")
    expect(page_text).not_to include("wrong path")
    expect(run_rows.size).to eq(1)
  end

  it "combines status and repository filters" do
    docs_source = create(:git_import_source, project:, repository_full_name: "matsuo-haruhito/docs-portal")
    other_source = create(:git_import_source, project:, repository_full_name: "matsuo-haruhito/docs-app")
    create_git_import_run!(git_import_source: docs_source, status: :failed, error_message: "target failure")
    create_git_import_run!(git_import_source: docs_source, status: :imported, summary_json: { "reason" => "same repo imported" })
    create_git_import_run!(git_import_source: other_source, status: :failed, error_message: "other failure")

    sign_in_as(admin_user)

    get admin_git_import_runs_path, params: { status: "failed", repository: "docs-portal" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示中の最新100件内の状態: 失敗: 1件")
    expect(page_text).to include("target failure")
    expect(page_text).not_to include("same repo imported")
    expect(page_text).not_to include("other failure")
    expect(run_rows.size).to eq(1)
  end

  it "does not fail on unsupported status values" do
    create_git_import_run!(summary_json: { "reason" => "visible run" })

    sign_in_as(admin_user)

    get admin_git_import_runs_path, params: { status: "archived" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("visible run")
    expect(page_text).to include("表示中: 1件 / 最新100件までを表示")
    expect(page_text).to include("表示中の最新100件内の状態: 取込済み: 1件")
  end

  it "shows the newest 100 runs after filters are applied" do
    limited_source = create(:git_import_source, project:, repository_full_name: "matsuo-haruhito/limited-history")
    101.times do |index|
      error_message = if index.zero?
        "oldest filtered boundary"
      elsif index == 100
        "newest filtered boundary"
      else
        "middle filtered boundary #{index}"
      end

      create_git_import_run!(
        git_import_source: limited_source,
        status: :failed,
        error_message:,
        created_at: Time.zone.parse("2026-05-01 00:00:00 UTC") + index.minutes
      )
    end
    other_source = create(:git_import_source, project:, repository_full_name: "matsuo-haruhito/other-history")
    create_git_import_run!(git_import_source: other_source, status: :failed, error_message: "other repository failure")

    sign_in_as(admin_user)

    get admin_git_import_runs_path, params: { status: "failed", repository: "limited-history" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示中: 100件 / 絞り込み後の最新100件までを表示")
    expect(page_text).to include("リポジトリ名は owner/repo の一部一致で検索します。")
    expect(page_text).to include("表示中の最新100件内の状態: 失敗: 100件")
    expect(run_rows.size).to eq(100)
    expect(page_text).to include("newest filtered boundary")
    expect(page_text).not_to include("oldest filtered boundary")
    expect(page_text).not_to include("other repository failure")
  end

  it "shows a filtered empty state with a clear link" do
    create_git_import_run!(status: :imported, summary_json: { "reason" => "not failed" })

    sign_in_as(admin_user)

    get admin_git_import_runs_path, params: { status: "failed", repository: "missing-repo", branch: "release", source_path: "docs", commit_sha: "abcdef" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示中: 0件 / 絞り込み後の最新100件までを表示")
    expect(page_text).to include("条件に一致するGit同期履歴はありません。")
    expect(page_text).to include("適用中の状態: 失敗。状態を「すべて」に戻すと、他の状態の履歴も確認できます。")
    expect(page_text).to include("適用中のリポジトリ: missing-repo。owner/repo の一部一致で探すため、検索語を短くすると見つかることがあります。")
    expect(page_text).to include("適用中のブランチ: release。ブランチ名の一部で探すため、検索語を短くすると見つかることがあります。")
    expect(page_text).to include("適用中の取込元パス: docs。パスの一部で探すため、検索語を短くすると見つかることがあります。")
    expect(page_text).to include("適用中のコミット: abcdef。commit SHA は前方一致で探すため、先頭から短めに入力すると見つかることがあります。")
    expect(page_text).to include("絞り込み解除")

    clear_filter_link = filtered_empty_state_card.at_css(".actions a.button.secondary")
    expect(clear_filter_link.text.squish).to eq("絞り込み解除")
    expect(clear_filter_link["href"]).to eq(admin_git_import_runs_path)

    expect(page_text).not_to include("表示中の最新100件内の状態")
    expect(response.body).not_to include("Git同期履歴の表示設定")
  end

  it "forbids external users" do
    sign_in_as(external_user)

    get admin_git_import_runs_path

    expect(response).to have_http_status(:forbidden)
  end
end
