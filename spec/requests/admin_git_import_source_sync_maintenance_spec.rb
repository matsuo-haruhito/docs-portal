require "rails_helper"

RSpec.describe "Admin git import source sync maintenance mode", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "GITMAINT", name: "Git Maintenance Project") }
  let(:git_import_source) do
    create(
      :git_import_source,
      project:,
      repository_full_name: "example/maintenance-docs",
      branch: "release/main",
      source_path: "docs/current",
      created_by: admin_user
    )
  end

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

  before do
    sign_in_as(admin_user)
  end

  describe "when read-only maintenance is enabled" do
    let(:maintenance_env_value) { "1" }

    it "keeps Git import source settings and run history readable" do
      create_git_import_run!

      get admin_git_import_sources_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Git連携")
      expect(response.body).to include(git_import_source.repository_full_name)

      get edit_admin_git_import_source_path(git_import_source)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(git_import_source.repository_full_name)

      get admin_git_import_runs_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Git同期履歴")
      expect(response.body).to include(git_import_source.repository_full_name)
    end

    it "blocks manual sync without starting the syncer or creating a run" do
      allow(GitImportSourceSyncer).to receive(:new)

      expect do
        post sync_admin_git_import_source_path(git_import_source)
      end.not_to change(GitImportRun, :count)

      expect(response).to redirect_to(edit_admin_git_import_source_path(git_import_source))
      expect(GitImportSourceSyncer).not_to have_received(:new)

      follow_redirect!

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("メンテナンス中のためGit手動同期は停止しています")
      expect(response.body).to include("Git連携設定と同期履歴の閲覧は継続できます")
    end
  end

  describe "when read-only maintenance is disabled" do
    let(:maintenance_env_value) { nil }

    it "keeps the existing manual sync behavior" do
      run = GitImportRun.new(status: :imported)
      syncer = instance_double(GitImportSourceSyncer, call: run)
      expect(GitImportSourceSyncer).to receive(:new).with(source: git_import_source, actor: admin_user).and_return(syncer)

      post sync_admin_git_import_source_path(git_import_source)

      expect(response).to redirect_to(admin_git_import_runs_path)
      expect(flash[:notice]).to eq("Git同期を実行しました。status=imported")
    end
  end

  def create_git_import_run!
    GitImportRun.create!(
      git_import_source:,
      repository_full_name: git_import_source.repository_full_name,
      branch: git_import_source.branch,
      source_path: git_import_source.source_path,
      provider: :github,
      import_mode: :pull,
      status: :imported,
      commit_sha: "abcdef1234567890",
      summary_json: { imported: 1 }
    )
  end
end
