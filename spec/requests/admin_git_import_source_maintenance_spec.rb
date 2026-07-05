require "rails_helper"

RSpec.describe "Admin git import source maintenance mode", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "GIT-MAINT", name: "Git Maintenance") }

  around do |example|
    original_value = ENV[Admin::GitImportSourcesController::READ_ONLY_MAINTENANCE_ENV]
    ENV[Admin::GitImportSourcesController::READ_ONLY_MAINTENANCE_ENV] = maintenance_env_value
    example.run
  ensure
    if original_value.nil?
      ENV.delete(Admin::GitImportSourcesController::READ_ONLY_MAINTENANCE_ENV)
    else
      ENV[Admin::GitImportSourcesController::READ_ONLY_MAINTENANCE_ENV] = original_value
    end
  end

  def git_import_source_params(repository_full_name: "example/maintenance-docs", branch: "main", enabled: "1", credential_secret: "")
    {
      project_id: project.id,
      provider: "github",
      organization_name: "example-org",
      repository_full_name:,
      branch:,
      source_path: "docs",
      auth_type: "github_app",
      installation_id: "12345",
      credential_ref: "git/#{repository_full_name}",
      credential_secret:,
      enabled:
    }
  end

  def page_text
    Nokogiri::HTML(response.body).text.squish
  end

  describe "when read-only maintenance is enabled" do
    let(:maintenance_env_value) { "1" }

    it "keeps source list, filters, project lookup, and sync history readable" do
      sign_in_as(admin_user)
      source = create(
        :git_import_source,
        project:,
        repository_full_name: "example/read-only-docs",
        branch: "release/main",
        source_path: "docs/current",
        enabled: true
      )

      get admin_git_import_sources_path, params: { q: "read-only", project_id: project.id, enabled: "true" }

      expect(response).to have_http_status(:ok)
      expect(page_text).to include(source.repository_full_name)
      expect(page_text).to include("現在の絞り込み: 検索語: read-only / 案件: GIT-MAINT / Git Maintenance / 状態: 有効")

      get project_search_admin_git_import_sources_path(format: :json), params: { q: "git-maint" }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).fetch("options")).to contain_exactly(
        include("value" => project.id, "text" => "GIT-MAINT / Git Maintenance")
      )

      get admin_git_import_runs_path

      expect(response).to have_http_status(:ok)
      expect(page_text).to include("Git同期履歴")
    end

    it "blocks source creation before saving settings" do
      sign_in_as(admin_user)

      expect do
        post admin_git_import_sources_path, params: {
          git_import_source: git_import_source_params(repository_full_name: "example/blocked-create")
        }
      end.not_to change(GitImportSource, :count)

      expect(response).to redirect_to(admin_git_import_sources_path)

      follow_redirect!

      expect(response).to have_http_status(:ok)
      expect(page_text).to include("メンテナンス中のためGit連携設定の変更は停止しています")
    end

    it "blocks source updates without changing credentials or enabled state" do
      sign_in_as(admin_user)
      source = create(
        :git_import_source,
        project:,
        repository_full_name: "example/original-docs",
        branch: "main",
        auth_type: :github_app,
        credential_secret: "existing-secret",
        enabled: true
      )

      patch admin_git_import_source_path(source), params: {
        git_import_source: git_import_source_params(
          repository_full_name: "example/changed-docs",
          branch: "maintenance",
          enabled: "0",
          credential_secret: "changed-secret"
        )
      }

      expect(response).to redirect_to(admin_git_import_sources_path)
      source.reload
      expect(source.repository_full_name).to eq("example/original-docs")
      expect(source.branch).to eq("main")
      expect(source.credential_secret).to eq("existing-secret")
      expect(source.enabled).to be(true)
    end

    it "blocks source deletion" do
      sign_in_as(admin_user)
      source = create(:git_import_source, project:, repository_full_name: "example/delete-docs")

      expect do
        delete admin_git_import_source_path(source)
      end.not_to change(GitImportSource, :count)

      expect(response).to redirect_to(admin_git_import_sources_path)
      expect(GitImportSource.exists?(source.id)).to be(true)
    end
  end

  describe "when read-only maintenance is disabled" do
    let(:maintenance_env_value) { nil }

    it "keeps the existing create, update, and destroy behavior" do
      sign_in_as(admin_user)

      post admin_git_import_sources_path, params: {
        git_import_source: git_import_source_params(repository_full_name: "example/allowed-create")
      }

      expect(response).to redirect_to(admin_git_import_sources_path)
      source = GitImportSource.find_by!(repository_full_name: "example/allowed-create")

      patch admin_git_import_source_path(source), params: {
        git_import_source: git_import_source_params(
          repository_full_name: "example/allowed-update",
          branch: "release/main",
          enabled: "0"
        )
      }

      expect(response).to redirect_to(admin_git_import_sources_path)
      expect(source.reload.repository_full_name).to eq("example/allowed-update")
      expect(source.branch).to eq("release/main")
      expect(source.enabled).to be(false)

      expect do
        delete admin_git_import_source_path(source)
      end.to change(GitImportSource, :count).by(-1)
    end
  end
end
