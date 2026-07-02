require "rails_helper"

RSpec.describe "Admin git import sources", type: :request do
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

  def git_import_source_params(project:, repository_full_name:, auth_type:, credential_secret: nil)
    {
      project_id: project.id,
      provider: "github",
      organization_name: "example-org",
      repository_full_name:,
      branch: "main",
      source_path: "docs",
      auth_type:,
      installation_id: "12345",
      credential_ref: "git/#{repository_full_name}",
      credential_secret:,
      enabled: "1"
    }
  end

  it "shows manual source field cues on the form" do
    get admin_git_import_sources_path

    expect(response).to have_http_status(:ok)
    expect(parsed_html.at_css(%(input[name="git_import_source[repository_full_name]"]))["placeholder"]).to eq("owner/repo")
    expect(parsed_html.at_css(%(input[name="git_import_source[branch]"]))["placeholder"]).to eq("main")
    expect(parsed_html.at_css(%(input[name="git_import_source[source_path]"]))["placeholder"]).to eq("docs/source")
    expect(page_text).to include("既定ブランチ名を入力します。例: main")
    expect(page_text).to include("リポジトリルートからの相対パスです。例: docs / docs/source")
    expect(page_text).to include("リポジトリ、ブランチ、取込元パスは同期対象を指定する手入力項目です。")
    expect(page_text).to include("GitHub App picker は未実装のため、現在は値を直接入力します。")
  end

  it "shows auth type and advanced setting cues on the new and edit forms" do
    get admin_git_import_sources_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("通常運用は GitHub App。Fine-grained PAT は開発・検証用、認証なしは公開リポジトリ限定です。")
    expect(page_text).to include("詳細設定は、GitHub App の installation ID や PAT の参照名・secret を確認するときだけ開きます。")
    expect(page_text).to include("GitHub App では installation ID を確認します。")
    expect(page_text).to include("Fine-grained PAT では credential ref と secret を使い、no_auth では secret は不要です。")
    expect(page_text).to include("Fine-grained PAT を使う場合のみ入力します。")
    expect(page_text).to include("GitHub App や公開リポジトリの認証なしでは空欄のまま保存できます。")

    project = create(:project, code: "GITAUTH", name: "Auth Project")
    source = create(
      :git_import_source,
      project:,
      created_by: admin_user,
      repository_full_name: "example/auth-docs",
      auth_type: :github_app,
      credential_secret: ""
    )

    get edit_admin_git_import_source_path(source)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("保存済みシークレットは表示しません。Fine-grained PAT の値を変更するときだけ入力します。")
    expect(page_text).to include("GitHub App や認証なしの設定では空欄のまま保存できます。")
  end

  it "filters the source list by repository, branch, and source path fragments" do
    project = create(:project, code: "GIT001", name: "Main Docs")
    create(
      :git_import_source,
      project:,
      repository_full_name: "example/alpha-docs",
      branch: "release/main",
      source_path: "docs/current"
    )
    create(
      :git_import_source,
      project:,
      repository_full_name: "example/beta-docs",
      branch: "preview",
      source_path: "archive/content"
    )

    get admin_git_import_sources_path, params: { q: "ALPHA" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("example/alpha-docs")
    expect(page_text).not_to include("example/beta-docs")
    expect(page_text).to include("現在の絞り込み: 検索語: ALPHA")
    expect(page_text).to include("検索結果: 1件")

    get admin_git_import_sources_path, params: { q: "release/main" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("example/alpha-docs")
    expect(page_text).not_to include("example/beta-docs")

    get admin_git_import_sources_path, params: { q: "archive/content" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("example/beta-docs")
    expect(page_text).not_to include("example/alpha-docs")
  end

  it "filters the source list by project and enabled state" do
    target_project = create(:project, code: "GIT001", name: "Target Docs")
    other_project = create(:project, code: "GIT002", name: "Other Docs")
    create(
      :git_import_source,
      project: target_project,
      repository_full_name: "example/enabled-docs",
      enabled: true
    )
    create(
      :git_import_source,
      project: target_project,
      repository_full_name: "example/disabled-docs",
      enabled: false
    )
    create(
      :git_import_source,
      project: other_project,
      repository_full_name: "example/other-docs",
      enabled: false
    )

    get admin_git_import_sources_path, params: { project_id: target_project.id, enabled: "false" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("example/disabled-docs")
    expect(page_text).not_to include("example/enabled-docs")
    expect(page_text).not_to include("example/other-docs")
    expect(page_text).to include("現在の絞り込み: 案件: GIT001 / Target Docs / 状態: 無効")
    expect(page_text).to include("検索結果: 1件")
  end

  it "keeps filters while moving between bounded list pages" do
    project = create(:project, code: "PAGE", name: "Paged Project")
    55.times do |index|
      create(
        :git_import_source,
        project:,
        repository_full_name: format("example/page-docs-%02d", index),
        branch: "main",
        source_path: "docs",
        enabled: true
      )
    end
    create(:git_import_source, repository_full_name: "example/other-docs")

    get admin_git_import_sources_path, params: { q: "page-docs", page: 2 }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示中: 51-55件 / 55件")
    expect(page_text).to include("2 / 2ページ")
    expect(page_text).to include("example/page-docs-50")
    expect(page_text).not_to include("example/page-docs-49")
    expect(page_text).not_to include("example/other-docs")
    expect(response.body).to include("q=page-docs")
  end

  it "separates a filtered empty result from the unregistered empty state" do
    project = create(:project, code: "GIT001", name: "Main Docs")
    create(:git_import_source, project:, repository_full_name: "example/main-docs")

    get admin_git_import_sources_path, params: { q: "missing-repository" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("条件に一致するGit連携設定はありません。")
    expect(page_text).to include("すべてのGit連携設定を見る")
    expect(page_text).not_to include("まだGit連携は登録されていません。")
  end

  it "shows the target project and sync destination in manual sync confirmations" do
    active_project = create(:project, code: "GIT001", name: "Main Docs")
    disabled_project = create(:project, code: "GIT002", name: "Archive Docs")
    create(
      :git_import_source,
      project: active_project,
      repository_full_name: "example/shared-docs",
      branch: "release/main",
      source_path: "docs/current",
      enabled: true
    )
    disabled_source = create(
      :git_import_source,
      project: disabled_project,
      repository_full_name: "example/shared-docs",
      branch: "release/archive",
      source_path: "docs/archive",
      enabled: false
    )
    disabled_source.update_column(:source_path, "")

    get admin_git_import_sources_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(
      "Git連携設定を手動同期します。案件: GIT001 / Main Docs、リポジトリ: example/shared-docs、ブランチ: release/main、取込元パス: docs/current、状態: 有効"
    )
    expect(response.body).to include(
      "Git連携設定を手動同期します。案件: GIT002 / Archive Docs、リポジトリ: example/shared-docs、ブランチ: release/archive、取込元パス: /、状態: 無効"
    )
  end

  it "returns project options by code and name for the remote combobox" do
    alpha_project = create(:project, code: "GIT001", name: "Alpha Docs")
    beta_project = create(:project, code: "OPS002", name: "Beta Archive")

    get project_search_admin_git_import_sources_path(format: :json), params: { q: "git001" }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options")).to contain_exactly(
      include("value" => alpha_project.id, "text" => "GIT001 / Alpha Docs")
    )

    get project_search_admin_git_import_sources_path(format: :json), params: { q: "beta archive" }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options")).to contain_exactly(
      include("value" => beta_project.id, "text" => "OPS002 / Beta Archive")
    )
  end

  it "bounds project search results and handles long queries without a server error" do
    22.times do |index|
      create(:project, code: format("GIT%02d", index), name: "Bounded Project #{index}")
    end

    get project_search_admin_git_import_sources_path(format: :json), params: { q: "Bounded Project" }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options").size).to eq(Admin::GitImportSourcesController::PROJECT_SEARCH_LIMIT)

    long_query = "Bounded Project" + ("x" * 200)
    get project_search_admin_git_import_sources_path(format: :json), params: { q: long_query }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options")).to eq([])
  end

  it "restores a selected project even when it is outside the search result window" do
    22.times do |index|
      create(:project, code: format("AAA%02d", index), name: "Listed Project #{index}")
    end
    selected_project = create(:project, code: "ZZZ99", name: "Selected Project")

    get selected_project_admin_git_import_sources_path(format: :json), params: { id: selected_project.id }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("option")).to include(
      "value" => selected_project.id,
      "text" => "ZZZ99 / Selected Project"
    )

    get selected_project_admin_git_import_sources_path(format: :json), params: { id: "999999" }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("option")).to be_nil
  end

  it "keeps an existing credential secret when the edit form submits a blank secret" do
    project = create(:project, code: "GITSECRET", name: "Secret Project")
    source = create(
      :git_import_source,
      project:,
      created_by: admin_user,
      repository_full_name: "example/secret-docs",
      auth_type: :fine_grained_pat,
      credential_secret: "existing-token"
    )

    patch admin_git_import_source_path(source), params: {
      git_import_source: git_import_source_params(
        project:,
        repository_full_name: source.repository_full_name,
        auth_type: "fine_grained_pat",
        credential_secret: ""
      )
    }

    expect(response).to redirect_to(admin_git_import_sources_path)
    expect(source.reload.credential_secret).to eq("existing-token")
    expect(source.auth_type).to eq("fine_grained_pat")
  end

  it "preserves the current secret requirement for pull auth types" do
    project = create(:project, code: "GITAUTH", name: "Auth Project")

    post admin_git_import_sources_path, params: {
      git_import_source: git_import_source_params(
        project:,
        repository_full_name: "example/missing-secret",
        auth_type: "fine_grained_pat",
        credential_secret: ""
      )
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(GitImportSource.exists?(repository_full_name: "example/missing-secret")).to be(false)

    post admin_git_import_sources_path, params: {
      git_import_source: git_import_source_params(
        project:,
        repository_full_name: "example/github-app-docs",
        auth_type: "github_app",
        credential_secret: ""
      )
    }

    expect(response).to redirect_to(admin_git_import_sources_path)
    expect(GitImportSource.find_by!(repository_full_name: "example/github-app-docs").credential_secret).to be_blank

    post admin_git_import_sources_path, params: {
      git_import_source: git_import_source_params(
        project:,
        repository_full_name: "example/public-docs",
        auth_type: "no_auth",
        credential_secret: ""
      )
    }

    expect(response).to redirect_to(admin_git_import_sources_path)
    expect(GitImportSource.find_by!(repository_full_name: "example/public-docs").credential_secret).to be_blank
  end
end
