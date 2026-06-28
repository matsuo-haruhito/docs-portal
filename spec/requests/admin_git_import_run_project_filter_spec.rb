require "rails_helper"

RSpec.describe "Admin git import run project filter", type: :request do
  let(:admin_user) { create(:user, :internal) }

  before do
    sign_in_as(admin_user)
  end

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def json_body
    JSON.parse(response.body)
  end

  def run_rows
    parsed_html.css("table tbody tr")
  end

  def create_git_import_run!(git_import_source:, created_at: Time.zone.parse("2026-05-01 00:00:00 UTC"), status: :imported, summary_json: { reason: "visible run" }, error_message: nil, commit_sha: "abcdef1234567890")
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

  it "returns project options by code and name for the run filter combobox" do
    alpha_project = create(:project, code: "GIR001", name: "Run Alpha")
    beta_project = create(:project, code: "OPS002", name: "Run Beta Archive")

    get project_search_admin_git_import_runs_path(format: :json), params: { q: "gir001" }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options")).to contain_exactly(
      include("value" => alpha_project.id, "text" => "GIR001 / Run Alpha")
    )

    get project_search_admin_git_import_runs_path(format: :json), params: { q: "beta archive" }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options")).to contain_exactly(
      include("value" => beta_project.id, "text" => "OPS002 / Run Beta Archive")
    )
  end

  it "bounds project search results and restores a selected project outside the search window" do
    22.times do |index|
      create(:project, code: format("AAA%02d", index), name: "Listed Run Project #{index}")
    end
    selected_project = create(:project, code: "ZZZ99", name: "Selected Run Project")

    get project_search_admin_git_import_runs_path(format: :json), params: { q: "Listed Run Project" }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options").size).to eq(Admin::GitImportRunsController::PROJECT_SEARCH_LIMIT)

    long_query = "Listed Run Project" + ("x" * 200)
    get project_search_admin_git_import_runs_path(format: :json), params: { q: long_query }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options")).to eq([])

    get selected_project_admin_git_import_runs_path(format: :json), params: { id: selected_project.id }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("option")).to include(
      "value" => selected_project.id,
      "text" => "ZZZ99 / Selected Run Project"
    )

    get selected_project_admin_git_import_runs_path(format: :json), params: { id: "999999" }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("option")).to be_nil
  end

  it "filters runs by project without changing the latest 100 boundary or table preferences" do
    target_project = create(:project, code: "GIR001", name: "Target Run Project")
    other_project = create(:project, code: "GIR002", name: "Other Run Project")
    target_source = create(:git_import_source, project: target_project, repository_full_name: "example/target-docs")
    other_source = create(:git_import_source, project: other_project, repository_full_name: "example/other-docs")
    create_git_import_run!(git_import_source: target_source, summary_json: { reason: "target project run" })
    create_git_import_run!(git_import_source: other_source, summary_json: { reason: "other project run" })

    get admin_git_import_runs_path, params: { project_id: target_project.id }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示中: 1件 / 絞り込み後の最新100件までを表示")
    expect(page_text).to include("Target Run Project")
    expect(page_text).to include("target project run")
    expect(page_text).not_to include("other project run")
    expect(response.body).to include("Git同期履歴の表示設定")
    expect(response.body).to include('data-rails-table-preferences-column-key="project"')
    expect(run_rows.size).to eq(1)
  end

  it "combines status, repository, and project filters as AND conditions" do
    target_project = create(:project, code: "GIRAND", name: "AND Project")
    other_project = create(:project, code: "GIROTHER", name: "Other AND Project")
    target_source = create(:git_import_source, project: target_project, repository_full_name: "example/and-docs")
    same_project_other_repo = create(:git_import_source, project: target_project, repository_full_name: "example/other-repo")
    other_project_source = create(:git_import_source, project: other_project, repository_full_name: "example/and-docs")

    create_git_import_run!(git_import_source: target_source, status: :failed, error_message: "target failure")
    create_git_import_run!(git_import_source: target_source, status: :imported, summary_json: { reason: "status miss" })
    create_git_import_run!(git_import_source: same_project_other_repo, status: :failed, error_message: "repository miss")
    create_git_import_run!(git_import_source: other_project_source, status: :failed, error_message: "project miss")

    get admin_git_import_runs_path, params: { status: "failed", repository: "and-docs", project_id: target_project.id }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示中の最新100件内の状態: 失敗: 1件")
    expect(page_text).to include("target failure")
    expect(page_text).not_to include("status miss")
    expect(page_text).not_to include("repository miss")
    expect(page_text).not_to include("project miss")
    expect(run_rows.size).to eq(1)
  end

  it "shows the selected project in the filtered empty state" do
    source_project = create(:project, code: "GIRHAS", name: "Has Runs")
    empty_project = create(:project, code: "GIREMPTY", name: "Empty Run Project")
    source = create(:git_import_source, project: source_project, repository_full_name: "example/has-runs")
    create_git_import_run!(git_import_source: source, summary_json: { reason: "not selected" })

    get admin_git_import_runs_path, params: { project_id: empty_project.id }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示中: 0件 / 絞り込み後の最新100件までを表示")
    expect(page_text).to include("条件に一致するGit同期履歴はありません。")
    expect(page_text).to include("適用中の案件: GIREMPTY / Empty Run Project。案件コード・案件名で検索し直すと、別の案件の履歴も確認できます。")
    expect(page_text).to include("絞り込み解除")
    expect(response.body).not_to include("Git同期履歴の表示設定")
  end
end
